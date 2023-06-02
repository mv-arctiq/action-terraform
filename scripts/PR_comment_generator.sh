#!/bin/bash
TF_STEP_TYPE=$1
TF_STEP_STATUS=$2
TF_STEP_DIRECTORY=$3
TF_STEP_OUTPUT=$4
if [[ $5 != "" ]]; then
	TF_STEP_OUTPUT_SIZE_LIMIT=$5
else
	TF_STEP_OUTPUT_SIZE_LIMIT=65000
fi

####
# FUNCTIONS
####
log_error() {
	error_message=$(cat <<-END
	Some parameters provided to the script are missing. Parameters provided:
	- TF_STEP_TYPE=$TF_STEP_TYPE
	- TF_STEP_STATUS=$TF_STEP_STATUS
	- TF_STEP_DIRECTORY=$TF_STEP_DIRECTORY
	- TF_STEP_OUTPUT=$TF_STEP_OUTPUT
	- TF_STEP_OUTPUT_SIZE_LIMIT=$TF_STEP_OUTPUT_SIZE_LIMIT
	END
	)

	echo "::error title=Missing script arguments::${error_message}"
}

generate_comment() {
	set pr_comment_title
	set pr_comment_tmp_filepath
	pr_comment_tmp_filename="tf_${TF_STEP_TYPE}_pr_comment.md"

	if [[ $TF_STEP_STATUS == "success" ]]; then
		pr_symbol=":white_check_mark:"
	else
		pr_symbol=":x:"
	fi

	# COMMENT TITLE
	# If provided, display directory in the comment where terraform files are located.
	if [[ $TF_STEP_DIRECTORY != "" ]]; then
		pr_comment_title="<b>Terraform \`${TF_STEP_TYPE}\` ${TF_STEP_STATUS} in  \`${TF_STEP_DIRECTORY}\` directory</b> ${pr_symbol}"
		pr_comment_tmp_filepath="${TF_STEP_DIRECTORY}/${pr_comment_tmp_filename}"
	else
		pr_comment_title="<b>Terraform \`${TF_STEP_TYPE}\` ${TF_STEP_STATUS}</b> ${pr_symbol}"
		pr_comment_tmp_filepath="${pr_comment_tmp_filename}"
	fi

	# COMMENT BODY
	# Format outputs based on the type of command executed (e.g: terraform init, terraform fmt..)
	if [[ "$TF_STEP_TYPE" =~ ^(init|validate)$ ]]; then
		# Truncate color from tf output for github comment compatibility using sed.
		pr_comment_tf_output=$(cat "${TF_STEP_OUTPUT}" | sed 's/\x1b\[[0-9;]*m//g')
		pr_comment_code_block_type="terraform"
	elif [[ "$TF_STEP_TYPE" == "fmt" ]]; then
		pr_comment_tf_output=$(cat "${TF_STEP_OUTPUT}")
		pr_comment_code_block_type="diff"
	elif [[ "$TF_STEP_TYPE" == "plan" ]]; then
		pr_comment_tf_output=$(cat "${TF_STEP_OUTPUT}" | sed 's/\x1b\[[0-9;]*m//g')
		pr_comment_tf_output=$(sed -r '/Plan: /q' <<<"${pr_comment_tf_output}")
		#pr_comment_tf_output=$(sed -r 's/^([[:blank:]]*)([-+~])/\2\1/g' <<<"${pr_comment_tf_output}")
		pr_comment_code_block_type="terraform"
	fi

	if [[ ${#pr_comment_tf_output} -gt ${TF_STEP_OUTPUT_SIZE_LIMIT} ]]; then
		pr_comment_tf_output="Output is too big to fit in pull request comment because of Github PR comment size limitation. Please check the logs instead."
	fi

	# Write Pull Request body to a tmp file
	cat <<-EOF > $pr_comment_tmp_filepath
	<hr>
	
	${pr_comment_title}
	
	<details><summary>Show Output</summary>
	
	\`\`\`${pr_comment_code_block_type}
	${pr_comment_tf_output}
	\`\`\`
	
	</details>
	EOF

	# Display comment generated in the logs
	cat $pr_comment_tmp_filepath

	# Return filepath of the markdown comment generated to other steps
	echo "filepath=${pr_comment_tmp_filepath}" >> $GITHUB_OUTPUT
}

####
# WORKFLOW
####
if [[ $# -lt 4 ]]; then
	log_error
	exit 1
else
	generate_comment
	exit 0
fi
