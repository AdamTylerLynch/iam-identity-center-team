
# Enable StepFunction to assume role in Management Account for Create/DeleteAccountAssignment
# Update the AssumeRole tust policy to allow the Step Function to assume the role
GRANT_ROLE_ARN=$(aws stepfunctions describe-state-machine --name "TEAM-Grant-SM-main" --query 'definition.roleArn' --output text)
GRANT_ROLE_NAME=$(echo $GRANT_ROLE_ARN | awk -F'/' '{print $2}')

REVOKE_ROLE_ARN=$(aws stepfunctions describe-state-machine --name "TEAM-Revoke-SM-main" --query 'definition.roleArn' --output text)
REVOKE_ROLE_NAME=$(echo $REVOKE_ROLE_ARN | awk -F'/' '{print $2}')


# Get the ARN of the policy
assumePolicy=$(aws iam list-policies --query 'Policies[?PolicyName==`TEAMAssumeManagementRole`].Arn' --output text)
if [ -z "$assumePolicy" ]; then
 # Create a policy that allows the step function to assume a role in the management account
  echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::$MANAGEMENT_ACCOUNT:role/TEAMGrantRole",
            "Effect": "Allow"
        }
    ]
  }' > assume-management-policy.json

  # Create IAM policy named TEAMGrantRevoke
  aws iam create-policy --policy-name TEAMAssumeManagementRole --policy-document file://assume-management-policy.json --region $REGION
  # Get the ARN of the policy
  ASSUME_MANAGEMENT_POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`TEAMAssumeManagementRole`].Arn' --output text)

  # Attach the policy to the roles
  aws iam attach-role-policy --role-name $GRANT_ROLE_NAME --policy-arn $ASSUME_MANAGEMENT_POLICY_ARN --region $REGION
  aws iam attach-role-policy --role-name $REVOKE_ROLE_NAME --policy-arn $ASSUME_MANAGEMENT_POLICY_ARN --region $REGION
fi

#Switch to the management account and update the trust policy for the TEAMGrantRole so the TEAM step functions can assume it
export AWS_PROFILE=$ORG_MASTER_PROFILE

grantRole=`aws iam get-role --role-name TEAMGrantRole --region $REGION `
if [ -z "$grantRole" ]; then    
    # Create a Trust Policy for the IAM Role
    echo '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "$GRANT_ROLE_ARN"
            },
            "Action": "sts:AssumeRole"
        },
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "$REVOKE_ROLE_ARN"
            },
            "Action": "sts:AssumeRole"
        }
    ]
    }' > trust-policy.json
    aws iam update-assume-role-policy --role-name TEAMGrantRole --policy-document file://trust-policy.json --region $REGION
fi