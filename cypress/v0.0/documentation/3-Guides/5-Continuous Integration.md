slug: continuous-integration
excerpt: Run Cypress in any CI provider

# Contents

- :fa-angle-right: [Supported Services](#section-supported-services)
- :fa-angle-right: [Running in CI](#section-running-in-ci)
  - [Add your project to your CI provider](#section-add-you-project-to-your-ci-provider)
  - [Acquire a Cypress secret key](#section-acquire-a-cypress-secret-key)
  - [Add 2 lines of code to your CI config file](#section-add-2-lines-of-code-to-your-ci-config-file)
- :fa-angle-right: [Environment Variables](#section-environment-variables)
  - [Cypress CI Key](#section-cypress-ci-key)
  - [Cypress Version](#section-cypress-version)
  - [Cypress Project Id](#section-cypress-project-id)
- :fa-angle-right: [Examples](#section-examples)
  - [CircleCI](#section-circleci)
  - [Travis CI](#section-travis-ci)
  - [Codeship](#section-codeship)

***

# Supported Services

Cypress should run on **all** CI providers. We currently have seen Cypress working on the following providers:

- Jenkins (Linux)
- TravisCI
- CircleCI
- CodeShip
- GitLab

If you're running on your own `Jenkins` server you may have to install some other dependencies [which are documented here](https://on.cypress.io/guides/troubleshooting).

***

# Running in CI

Running Cypress in CI is very easy. If you're using a hosted CI service, generally the workflow is the same:

1. [Add your project's repo to your CI provider](#section-add-your-project-to-your-ci-provider)
2. [Acquire a Cypress secret key](#section-acquire-a-cypress-secret-key)
3. [Add 2 lines of code to your CI config file](#section-add-2-lines-of-code-to-your-ci-config-file)

***

## Add your project to your CI provider

This is different for each provider, but usually includes logging into your CI service, connecting it with your Github account, and then adding that project's repo.

***

## Acquire a Cypress secret key

Cypress verifies that your project is allowed to run in CI by using a secret key. This key can only be obtained from the Cypress CLI tool (currently). If you haven't installed the Cypress CLI tool, run the following command from your terminal:

```shell
# install the Cypress CLI tool
npm install -g cypress-cli
```

Run this following Cypress command from your terminal:

```shell
# this will return your secret key
cypress get:key
```

```shell
# you'll see a key that looks like this
703b33d9-a00e-4c66-90c2-40efc0fee2c6
```

![get-key](https://cloud.githubusercontent.com/assets/1268976/9291525/8ea13f28-4393-11e5-955e-1a41fee12f5f.gif)

[block:callout]
{
  "type": "info",
  "body": "`cypress get:key` expects your `pwd` to be that of your project."
}
[/block]

***

## Add 2 lines of code to your CI config file

Depending on which CI provider you're using you'll have access to a configuration file such as:

- `.travis.yml`
- `circle.yml`

You'll only need to add two lines of code to this file to run Cypress tests.

```text
# this will install the cypress-cli tools
npm install -g cypress-cli
```

```text
# this will run tests headlessly
cypress ci <your-secret-key>
```

You'll want to refer to your CI providers documentation for knowing when to run those commands. Generally each CI provider gives you a lifecyle of build commands.

For instance, with [Travis CI](https://docs.travis-ci.com/user/customizing-the-build/#The-Build-Lifecycle) they expose a `before_install` and `script` phase. You'd write `npm install -g cypress-cli` in the `before_install` phase, and `cypress ci` in the `script` phase.

***

# Environment variables

## Cypress CI Key

Instead of hard-coding your secret key into a configuration file, you can opt to store this as an environment variable with your CI provider. This prevents your secret key from being stored in version control. Each CI provider will be different, but generally each exposes a way to set environment variables.

Set the name of the environment variable to `CYPRESS_CI_KEY` and paste your secret key as the value.

**Example of Env Variable in CircleCI**
![screen shot 2016-03-28 at 11 38 36 am](https://cloud.githubusercontent.com/assets/1271364/14081640/b5a25e52-f4d9-11e5-977b-43e209809716.png)


Then run your tests in CI by simply calling:

```yaml
# this will run tests headlessly
cypress ci
```

***

## Cypress Version

You can specify a specific version of Cypress to use in CI by setting an Environment Variable: `CYPRESS_VERSION`.

**Example of Env Variable in Codeship**
![screen shot 2016-03-28 at 11 28 26 am](https://cloud.githubusercontent.com/assets/1271364/14081365/601e2da4-f4d8-11e5-8ea8-0491ffcb0999.png)

As long as a previous version has not been removed (due to security issues) this will work.

***


## Cypress Project Id

You can specify a specific project ID in CI by setting an Environment Variable: `CYPRESS_PROJECT_ID`. The `projectId` value can be found in your [`cypress.json`](https://on.cypress.io/guides/configuration) file generated when first running tests in Cypress.

**Example of Env Variable in Travis CI**
![screen shot 2016-03-28 at 11 32 50 am](https://cloud.githubusercontent.com/assets/1271364/14081563/5e2ede20-f4d9-11e5-9e3f-38d052e8f104.png)

***

# Examples

## CircleCI

- [Kitchen Sink Example](https://circleci.com/gh/cypress-io/cypress-example-kitchensink)
- [Pie Chopper Example](https://circleci.com/gh/cypress-io/cypress-example-piechopper)

## Travis CI

- [Kitchen Sink Example](https://travis-ci.org/cypress-io/cypress-example-kitchensink)
- [TodoMVC Example](https://travis-ci.org/cypress-io/cypress-example-todomvc)

![travis-logs](https://cloud.githubusercontent.com/assets/1268976/9291527/8ea21024-4393-11e5-86b7-80e3b5d1047e.gif)

## Codeship

**Kitchen Sink Example Setup Commands**
```text
nvm install 5.3
npm install
npm install -g cypress-cli
npm start -- --silent &
```

**Kitchen Sink Example Test Commands**
```text
cypress ci
```

***

# Related

- [Reporters](https://on.cypress.io/guides/reporters)
