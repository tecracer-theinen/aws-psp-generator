# AWS PSP Generator

Generates Chef resources out of AWS API definitions. Used in the [AWS Platform Support Pack](https://supermarket.chef.io/cookbooks/aws-psp) workflow.

## Details

AWS has been publishing and updating a unified API under the name "CloudControl API" since 2021. It provides a list of all available resource types as well as type definitions and documentation via CloudFormation's type registry.

As REST APIs and desired state configuration have a huge overlap and the CloudControl API providing sufficient information, it is possible to convert these AWS definitions into usable Chef resources:

- Chef 18 includes native REST support and a DSL to define mappings
- train-rest 0.5.0 includes AWS v4 signature support
- the AWS Platform Support Pack includes code to deal with AWS API specialties and bring both parts together

## Usage

This generator is mostly viable for the AWS PSP itself, as it gets used in its nightly update cycle. Nevertheless, for manual adjustments and debugging it also offers a Thor-based CLI.


__All actions need valid AWS credentials. You can either use the `awsume` tool to get a temporary session or configure your AWS CLI credentials/environment variables.__

### Listing CloudControl Resources

The API does not cover all AWS resources yet. You can get a list of the supported ones by entering `aws-psp-generator list-resources` though.

### Generating Chef Resources

You can generate specific resources either in bulk or by individually specifying their name.

`aws-psp-generator generate-all` will retrieve all supported resources and overwrite any pre-existing ones. This will take a few minutes but already has exponential backoff and retry logic to avoid throttling by AWS.

Options:
- `--skip-existing` will only retrieve and add new resources, which are not present yet
- `--newer-than` takes an ISO8601 date and will only generate resources with an internal update after the specified time

`aws-psp-generator generate` takes one or more names of AWS resources (in `AWS::Service::Resource` syntax) and generate the corresponding Chef resources.

## Displaying Chef Resource definitions

`aws-psp-generator render` works identical to the `generate` command, but only displays the definition and does not write files.

## Changelog Management

`aws-psp-generator changelog` retrieves the list of AWS resources and determines if rendering them would result in new resources or actual differences in existing ones. The list of the anticipated changes gets printed to STDOUT and is used to create the changelog inside automated workflows

Options:
- `--newer-than` takes an ISO8601 date and will only check resources with an internal update after the specified time

## Autocompletion

`aws-psp-generator auto-complete` will output code for Bash's auto completion functionality.
