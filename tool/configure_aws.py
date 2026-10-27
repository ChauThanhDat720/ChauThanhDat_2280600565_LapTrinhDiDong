#!/usr/bin/env python3
"""Generate Flutter's public AWS settings from CloudFormation outputs.

Uses a local outputs JSON file, or a read-only AWS CLI describe-stacks request.
Never reads, exports or embeds AWS credentials, passwords or JWTs.
"""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MAPPING = {"AwsRegion": "AWS_REGION", "ApiBaseUrl": "API_BASE_URL",
           "CognitoUserPoolId": "COGNITO_USER_POOL_ID", "CognitoAppClientId": "COGNITO_APP_CLIENT_ID"}


def configuration(document):
    if isinstance(document, dict):
        if "Stacks" in document:
            if len(document["Stacks"]) != 1:
                raise ValueError("Cần outputs của đúng một stack.")
            document = document["Stacks"][0].get("Outputs", [])
        elif "Outputs" in document:
            document = document["Outputs"]
    if not isinstance(document, list):
        raise ValueError("Outputs phải là danh sách CloudFormation Outputs hoặc kết quả describe-stacks.")
    if any(not isinstance(item, dict) for item in document):
        raise ValueError("Outputs chứa mục không hợp lệ.")
    values = {item.get("OutputKey"): item.get("OutputValue") for item in document}
    result = {"BACKEND_MODE": "aws", "API_TIMEOUT_SECONDS": "20"}
    for key, define in MAPPING.items():
        value = values.get(key)
        if not isinstance(value, str) or not value.strip() or "REPLACE_ME" in value:
            raise ValueError("Thiếu output hợp lệ: " + key)
        result[define] = value.strip()
    region = result["AWS_REGION"]
    if not re.fullmatch(r"[a-z]{2}(?:-[a-z]+)+-\d", region):
        raise ValueError("AWS Region không hợp lệ.")
    if not result["COGNITO_USER_POOL_ID"].startswith(region + "_"):
        raise ValueError("User Pool và Region không khớp.")
    if not re.fullmatch(r"[A-Za-z0-9]+", result["COGNITO_APP_CLIENT_ID"]):
        raise ValueError("App Client ID không hợp lệ.")
    from urllib.parse import urlparse
    url = urlparse(result["API_BASE_URL"])
    if url.scheme != "https" or not url.hostname or url.username or url.password or url.query or url.fragment:
        raise ValueError("API URL phải là HTTPS và không có credentials, query hay fragment.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--outputs", type=Path, help="Local JSON file from CloudFormation outputs")
    source.add_argument("--stack-name", help="Read outputs using the AWS CLI")
    parser.add_argument("--region", default="ap-southeast-1")
    parser.add_argument("--profile")
    parser.add_argument("--output", type=Path, default=ROOT / "config/aws.local.json")
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    try:
        if args.outputs:
            document = json.loads(args.outputs.read_text(encoding="utf-8"))
        else:
            command = ["aws", "--region", args.region]
            if args.profile:
                command += ["--profile", args.profile]
            command += ["cloudformation", "describe-stacks", "--stack-name", args.stack_name, "--output", "json"]
            document = json.loads(subprocess.check_output(command, text=True))
        result = configuration(document)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        mode = "w" if args.force else "x"
        with args.output.open(mode, encoding="utf-8") as output:
            os.chmod(args.output, 0o600)
            json.dump(result, output, ensure_ascii=False, indent=2)
            output.write("\n")
        print("Đã tạo cấu hình Flutter: " + str(args.output))
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.exit(1, "Không thể tạo cấu hình: " + str(error) + "\n")


if __name__ == "__main__":
    main()
