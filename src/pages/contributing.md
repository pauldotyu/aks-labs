# Contributing to AKS Labs

This project welcomes contributions and suggestions.  Most contributions require you to agree to a Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us the rights to use your contribution. For details, visit [https://cla.opensource.microsoft.com](https://cla.opensource.microsoft.com).

When you submit a pull request, a CLA bot will automatically determine whether you need to provide a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

- [Code of Conduct](#coc)
- [Issues and Bugs](#issue)
- [Feature Requests](#feature)

## Code of Conduct {#coc}

Help us keep this project open and inclusive. Please read and follow our [Code of Conduct](https://opensource.microsoft.com/codeofconduct/).

## Found an Issue? {#issue}

If you find a bug in the source code or a mistake in the documentation, you can help us by [submitting an issue](#submit-issue) to the GitHub Repository. Even better, you can [submit a Pull Request](#submit-pr) with a fix.

## Want a Feature? {#feature}

You can *request* a new feature by [submitting an issue](#submit-issue) to the GitHub Repository. If you would like to *implement* a new feature, *please submit an issue with a proposal for your work first, to be sure that we can use it*.

- **Small Features** can be crafted and directly [submitted as a Pull Request](#submit-pr).

## Submitting an Issue {#submit-issue}

Before you submit an issue, search the archive, maybe your question was already answered.

If your issue appears to be a bug, and hasn't been reported, open a new issue.
Help us to maximize the effort we can spend fixing issues and adding new
features, by not reporting duplicate issues.  Providing the following information will increase the
chances of your issue being dealt with quickly:

- **Overview of the Issue** - if an error is being thrown a non-minified stack trace helps
- **Version** - what version is affected (e.g. 0.1.2)
- **Motivation for or Use Case** - explain what are you trying to do and why the current behavior is a bug for you
- **Browsers and Operating System** - is this a problem with all browsers?
- **Reproduce the Error** - provide a live example or a unambiguous set of steps
- **Related Issues** - has a similar issue been reported before?
- **Suggest a Fix** - if you can't fix the bug yourself, perhaps you can point to what might be
  causing the problem (line of code or commit)

You can file new issues by providing the above information at the corresponding repository's issues link: [https://github.com/Azure-Samples/aks-labs/issues/new](https://github.com/Azure-Samples/aks-labs/issues/new).

## Submitting a PR {#submit-pr}

Before you submit your Pull Request (PR) consider the following guidelines:

- Search the repository [https://github.com/Azure-Samples/aks-labs/pulls](https://github.com/Azure-Samples/aks-labs/pulls) for an open or closed PR
  that relates to your submission. You don't want to duplicate effort.
- Fork the repository and make your changes in your local fork.
- Commit your changes using a descriptive commit message
- Push your fork to GitHub:
- In GitHub, create a pull request
- If we suggest changes then:
  - Make the required updates.
  - Rebase your fork and force push to your GitHub repository (this will update your Pull Request):
    ```shell
    git rebase main -i
    git push -f
    ```

## Authoring a Workshop {#author-workshop}

When putting together your workshop, each workshop should be self-contained and should not rely on any other. Consider the time commitment required from users completing your workshop. Ideally, we want users to be able to complete a lab in **75 minutes**. If you think your workshop will take longer than that, please consider breaking it up into multiple workshops.


### Before You Author {#before-author}

Before creating content, check if your topic is already covered in Microsoft Learn. We are not trying to duplicate the content that is already available on [Microsoft Learn](https://learn.microsoft.com/training/browse/), so please check there first. If you find that your workshop is similar to existing content, please consider submitting a PR to update the existing content there instead of creating a new workshop here.

You might also want to consider exploring scenarios other than AKS features because the AKS team is already doing a great job of covering those in [AKS docs](https://learn.microsoft.com/azure/aks/). Ideally, you could explore end-to-end scenarios that may be missing from docs such as how to integrate AKS with other Azure services such as:

- Azure Functions
- Azure Logic Apps
- Azure DevOps
- other Azure services

You could also explore how to use AKS with other open-source tools like:

- Helm
- Istio
- ArgoCD

The possibilities are endless!

Finally, consider the scenario you are trying to cover. We want to make sure that the workshops are accessible to anyone who wants to learn. For example, while we are happy to have workshops that cover AI and ML, if your lab requires the use of more advanced tools like Azure OpenAI, please consider whether the audience will be able to complete the workshop without having to sign up for a paid service. So please keep this in mind when creating your content. If you are unsure whether your workshop is relevant or accessible, [please reach out to us](#submit-issue) and we can help you determine whether it is a good fit for the project.

### Getting Started {#getting-started}

To get started, you will need to fork this repository and clone it to your local machine. When you are ready to submit your workshop, you can create a pull request to the main branch of this repository.

### Style Guide {#style-guide}

This site is built using [Docusaurus](https://docusaurus.io/) and uses the default Docusaurus theme, so you can refer to their [style guide](https://docusaurus.io/docs/markdown-features) for more information. Check out the other workshop docs in the `docs` folder for examples of how to format your content. 

### Naming Files {#naming-files}

When creating a new workshop, you will need to create a new markdown file in the `docs` directory. The filename should be lowercase and use hyphens to separate words. For example, if you are creating a workshop on how to deploy an application to AKS, you might name your file `deploying-an-application-to-aks.md`.

### Writing Content {#writing-content}

At the top of the markdown file, you will need to add front matter so that Docusaurus can build and position the page within the left navigation correctly. The front-matter needs to be enclosed with three consecutive dashes `---` and include a `title`, `sidebar_position` at minimum. If you want the navigation to display a different label than the title, you can also include a `sidebar_label`.

Here is an example:

```markdown
---
title: Your Workshop Title
sidebar_label: Your Navigation Title # use only if you want to display a different label than the title
sidebar_position: 1                  # this dictates the order of the pages in the sidebar
---
```

The remaining content of the workshop is simple markdown with a few additional [markdown features](https://docusaurus.io/docs/markdown-features) provided by Docusaurus.


:::info

Also be sure to check out the [Docusaurus Tutorial](https://tutorial.docusaurus.io/docs/tutorial-basics/markdown-features) for more information on how to use its markdown features.

:::

Here is an example of what your markdown file might look like:

```markdown
# Title

Title of your page

## Objective

This is a short description of what the reader will learn in this workshop.

## Prerequisites

This is a list of what the reader needs to know and/or installed in their environment  before starting the workshop.

## Workshop Content

This is the content of the workshop. It can be a mix of text, code snippets, and images. Use the Docusaurus markdown features to format your content.
```

:::tip

When authoring content, you may want to draw special attention to certain sections of your content. Use Docusaurus's [admonitions](https://docusaurus.io/docs/markdown-features/admonitions) to do this.

:::

If your workshop content requires additional files, such as code samples, images, or other assets, use the `assets` directory that can be found in the root of the category folder. You can create subdirectories within the `assets` directory to organize your files.

:::info

When creating a folder to hold your workshop assets, name the folder the same as the markdown file so others will know which assets belong to which workshop.

:::

### Improving Accessibility {#improving-accessibility}

When authoring your workshop, please consider the accessibility of the content. This includes ensuring that the content is readable by screen readers and that any images included in the workshop are accessible to all users. 

When writing your content, please use headings to structure your content. This will help users who are using screen readers to navigate the content more easily.

#### Images

When taking screen shots to be included in workshop instructions, please use "light mode"" where possible and ensure your monitor is set to a resolution of 1920x1080. This will ensure that the images large enough to be readable by all users. Also, please be sure to include a description of the image in the markdown file so that users who are using screen readers can understand the content of the image.

#### URLs

If you are including URLs to refer readers to additional resources, please ensure to remove any locale specific URLs and use the global URLs instead. This will ensure that all users can access the content in their preferred language. This is especially important when pointing to Microsoft Learn content.

### Testing locally {#test-locally}

The site requires [Node.js](https://nodejs.org/en/download) to run locally. If you don't have Node.js installed, you can download it from the link provided or open this repo in [GitHub Codespaces](https://github.com/features/codespaces) or in a local DevContainer if you are using [VS Code](https://code.visualstudio.com/docs/remote/containers).

To render site locally, open a terminal and run following command from the root of the project:

```shell
npm install
npm start
```

This will start a local server that you can access at [http://localhost:3000](http://localhost:3000) to see your changes.

### Testing remotely {#test-remotely}

You may also want to have others test your workshop prior to submitting a PR. To test your changes remotely or share a publicly accessible URL with team members, you can deploy your changes to a GitHub Pages site by following these steps in your forked repository:

1. Navigate to the **Settings** tab
1. Click on **Pages** in the left navigation
1. In the **GitHub Pages** section, select **GitHub Actions** as the Source
1. Navigate to the **Actions** tab
1. If this is your first time running GitHub Actions in the repo, click on the green button that says **I understand my workflows, go ahead and enable them**. This will enable the GitHub Actions workflow to build and deploy your changes to GitHub Pages.
1. Click on the **Deploy to GitHub Pages** in the left navigation
1. Click the **Run workflow** button. This will trigger the workflow to build and deploy your changes to GitHub Pages. 

Once the workflow has completed, you can access your site at `https://<your-github-username>.github.io/aks-labs/`.

:::note

GitHub Pages in your forked repository will only build and deploy when changes are pushed to the main branch of your fork. To preview your workshop content before submitting a PR to the original repository, commit and push your changes to the main branch of your fork.

:::

That's it! Thank you for your contribution!
