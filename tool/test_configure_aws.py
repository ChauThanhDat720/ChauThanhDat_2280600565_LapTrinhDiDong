import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from configure_aws import configuration


def outputs():
    return [{"OutputKey": key, "OutputValue": value} for key, value in {
        "AwsRegion": "ap-southeast-1", "ApiBaseUrl": "https://example.execute-api.ap-southeast-1.amazonaws.com/v1",
        "CognitoUserPoolId": "ap-southeast-1_Example", "CognitoAppClientId": "123example",
        "ExtraUnrelatedValue": "should-not-enter-flutter-config",
    }.items()]


class ConfigurationTests(unittest.TestCase):
    def test_export_only_public_config_from_describe_stacks(self):
        result = configuration({"Stacks": [{"Outputs": outputs()}]})
        self.assertEqual(result["BACKEND_MODE"], "aws")
        self.assertEqual(result["COGNITO_APP_CLIENT_ID"], "123example")
        self.assertNotIn("ExtraUnrelatedValue", result)
        self.assertEqual(len(result), 6)

    def test_incomplete_or_wrong_region_is_rejected(self):
        with self.assertRaises(ValueError):
            configuration([])
        data = outputs()
        data[2]["OutputValue"] = "us-east-1_Wrong"
        with self.assertRaises(ValueError):
            configuration(data)

    def test_plain_http_and_placeholder_are_rejected(self):
        for bad in ["http://example.com", "https://user:password@example.com", "https://REPLACE_ME.example.com"]:
            data = outputs()
            data[1]["OutputValue"] = bad
            with self.assertRaises(ValueError):
                configuration(data)

    def test_cli_writes_config_without_overwriting_existing_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            source, target = Path(tmp) / "outputs.json", Path(tmp) / "aws.local.json"
            source.write_text(json.dumps(outputs()))
            command = ["python3", str(Path(__file__).with_name("configure_aws.py")), "--outputs", str(source), "--output", str(target)]
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(target.read_text())["BACKEND_MODE"], "aws")
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)
            self.assertEqual(subprocess.run(command + ["--force"], capture_output=True).returncode, 0)


if __name__ == "__main__":
    unittest.main()
