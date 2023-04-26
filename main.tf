data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

module "name" {
  source           = "github.com/ParisaMousavi/aws-naming"
  prefix           = var.prefix
  name             = var.name
  environment      = var.environment
  region_shortname = var.region_shortname
}

#------------------------------------------
#  Create policy definition JSON
#------------------------------------------
data "template_file" "lambda_policies" {
  template = file("${path.module}/lambda-policies/permissions.json")
  vars = {
    account_id = data.aws_caller_identity.current.account_id,
    region     = var.region
  }
}

#------------------------------------------
#  Create policy 
#------------------------------------------
resource "aws_iam_policy" "lambda_policy" {
  name        = module.name.policy
  path        = "/my-path/"
  description = "IAM policy for logging from a lambda"
  policy      = data.template_file.lambda_policies.rendered
}

#------------------------------------------
#  Create lambda assume role
#------------------------------------------
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

#------------------------------------------
#  Create lambda role
#------------------------------------------
resource "aws_iam_role" "lambda_role" {
  depends_on = [
    aws_iam_policy.lambda_policy
  ]
  name               = module.name.role
  path               = "/my-path/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

#------------------------------------------
#  attach lambda policies to lambda role
#------------------------------------------
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_security_group" "this" {
  name        = module.name.security_group
  description = "security group for lambda"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  tags = {
    Name = module.name.security_group
    By   = "parisamoosavinezhad@hotmail.com"
  }
}

data "archive_file" "this" {
  type        = "zip"
  source_file = "${path.module}/code/index.mjs"
  output_path = "${path.module}/output/code.zip"
}

module "lmb" {
  depends_on = [
    aws_iam_policy.lambda_policy,
    aws_iam_role.lambda_role
  ]
  source           = "github.com/ParisaMousavi/aws-lambda?ref=main"
  name             = module.name.lambda
  filename         = "${path.module}/output/code.zip"
  source_code_hash = data.archive_file.this.output_base64sha256
  role_arn         = aws_iam_role.lambda_role.arn
  environment_vars = {
    MY_VAR = "my value"
  }
  subnet_ids         = [data.terraform_remote_state.network.outputs.private_subnet_ids["private_1"], data.terraform_remote_state.network.outputs.private_subnet_ids["private_2"]]
  security_group_ids = [aws_security_group.this.id]
  event_source_arn   = null
  additional_tags = {
    By   = "parisamoosavinezhad@hotmail.com"
    Name = module.name.lambda
  }
}

# I used this website to develop this part
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration.html
resource "aws_api_gateway_rest_api" "this" {
  name        = module.name.api_gtw
  description = "Call Lambda"
  tags = {
    By   = "parisamoosavinezhad@hotmail.com"
    Name = module.name.lambda
  }
}

resource "aws_api_gateway_resource" "this" {
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.this.id
  path_part   = var.name
}

resource "aws_api_gateway_method" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.this.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "this" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.this.id
  http_method             = aws_api_gateway_method.this.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = module.lmb.invoke_arn
}

# use service principal for AWS services
# https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_policies_elements_principal.html#principal-services
resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = module.lmb.name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/${aws_api_gateway_method.this.http_method}${aws_api_gateway_resource.this.path}"
}
