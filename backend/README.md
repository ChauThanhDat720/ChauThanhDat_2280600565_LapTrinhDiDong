# Smart Hospital backend blueprint

This folder is an AWS SAM blueprint only. It does not create an AWS account,
deploy an API, create tables, buckets, IAM users, or incur AWS charges.

## Local checks

```sh
npm test
npm run format:check
```

If AWS SAM CLI is later installed and cloud resources are approved:

```sh
sam validate --template template.yaml
sam local start-api --template template.yaml
```

The public health endpoint is `GET /health`. All patient and appointment
endpoints require the Cognito authorizer in the SAM template. `sam local` test
events must provide a trusted authorizer claim; never bypass ownership checks in
production.

## Production replacement points

The in-memory repositories exist only for local handler tests. Before any
deployment, replace them with DynamoDB implementations that use the caller's
Cognito `sub` as the patient partition key. Add an S3 presigned-URL handler for
uploads; Flutter must never receive AWS access keys or secret keys.

See the root `README.md` for API contracts, DynamoDB schema, and Flutter setup.
