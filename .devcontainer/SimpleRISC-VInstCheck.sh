#!/bin/bash

# Check if the input file is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <input_file>"
  exit 1
fi

input_file="$1"

# Define the patterns to check for
# TODO: Check work here.
#patterns="li|lui|j\s|nop|mv|neg|sltz|srl|sll|xor|beqz|bne|call|sgtzli|lw\s|sw|add\s|addi\s|sub|and|or|slt|andi|ori|slti|beq|jal\s|jalr|ret|auipc|not|zext.b"
patterns="li|j\s|nop|mv|neg|sltz|srl|sll|xor|beqz|bne|call|sgtzli|lw\s|sw|add\s|addi\s|sub|and|or|slt|andi|ori|slti|beq|jal\s|auipc|not|zext.b"
# Set line number to 0
line_number=0
# Set error count to 0
error_count=0
# Read the file line by line
while IFS= read -r line; do
    # Keep track of the line number
  ((line_number++))
  if ! echo "$line" | grep -qE "//\s+($patterns)"; then
    echo "$input_file:$line_number: ERROR: Line may not contain an allowed instruction: $line"
    # Add to error count
    ((error_count++))
  fi
done < "$input_file"
# Return zero on success (error count is zero)
# Always return zero to avoid deleting the target?   Check with Makefile to ignore return.
exit 0
