---
layout: faq
title: General Questions
comments: false
containerClass: faq
---

<!-- # What is Cypress? -->


<!-- # Hasn’t this been done before? -->

# {% fa fa-angle-right %} How is this different from 'X' testing tool?

Cypress is kind of a hybrid application/framework/service all rolled into one. It takes a little bit of other testing tools, brings them together and improves on them.

**Mocha**

[Mocha](http://mochajs.org/) is a testing framework for JavaScript. Mocha gives you the `it`, `describe`, `beforeEach` methods. Cypress isn't **different** from Mocha, it actually **uses** Mocha under the hood. All of your tests will be written on top of Mocha's `bdd` interface.

**Karma**

[Karma](http://karma-runner.github.io/) is a unit testing runner for JavaScript, which can work with either `Jasmine`, `Mocha`, or another JavaScript testing framework.

Karma also watches your JavaScript files, live reloads when they change, and is also the `reporter` for your tests failing / passing. It runs from the command line.

Cypress essentially replaces Karma because it does all of this already and much more.

**Capybara**

[Capybara](http://teamcapybara.github.io/capybara/) is a `Ruby` specific tool that allows you to write integration tests for your web application. In the Rails world, this is the *go-to* tool for testing your application. It uses `Selenium` (or another headless driver) to interact with browsers. It's API consists of commands that query for DOM elements, perform user actions, navigate around, etc.

Cypress essentially replaces Capybara because it does all of these things and much more. The difference is that instead of testing your application in a GUI-less console, you'd see your application at all times. You'd never have to take a screenshot to debug because all commands instantly provide you the state of your application while they run. Upon any command failing, you'll get a human-readable error explaining why it failed. There's no "guessing" when debugging.

Oftentimes Capybara begins to not work as well in complex JavaScript applications. Additionally, trying to TDD your application is often difficult. You often have to resort to writing your application code first (typically manually refreshing your browser after changes) until you get it working. From there you write tests, but lose the entire value of TDD.

**Protractor**

[Protractor](http://www.protractortest.org/) is basically the `Capybara` of the JavaScript world. It provides a nice Promise-based interface on top of Selenium, which makes it easy to deal with asynchronous code. Protractor comes with all of the features of Capybara and essentially suffers from the same problems.

Cypress replaces Protractor because it does all of these things and much more. One major difference is that Cypress enables you to write your unit tests and integration tests in the same tool, as opposed to splitting up this work across both Karma and Protractor.

Also, Protractor is very much focused on `AngularJS`, whereas Cypress is designed to work with any JavaScript framework. Protractor, because it's based on Selenium, is still pretty slow, and is prohibitive when trying to TDD your application. Cypress, on the other hand, runs at the speed your browser and application are capable of serving and rendering, there is no additional bloat.

**SauceLabs**

[SauceLabs](https://saucelabs.com/) is a 3rd party tool which enables Selenium-based tests to be run across various browsers and operating systems. Additionally, they have a JavaScript Unit Testing tool that isn't Selenium focused.

SauceLabs also has a `manual testing` mode, where you can remotely control browsers in the cloud as if they were installed on your machine.

Cypress's API is written to be completely compatible with SauceLabs, even though our API is not Selenium based at all. We will be offering better integration with SauceLabs in the future.

Ultimately SauceLabs and Cypress offer very different value propositions. SauceLabs doesn't help you write your tests, it takes your existing tests and runs them across different browsers and aggregates the results for you.

Cypress on the other hand **helps** you write your tests. You would use Cypress every day, building and testing your application, and then use SauceLabs to ensure your application works on every browser.

# {% fa fa-angle-right %} Is Cypress free?

Cypress desktop app and CLI are free to use. The Cypress Dashboard is a premium feature for non-open source projects and offers recording videos, screenshots and logs in a web interface.

# {% fa fa-angle-right %} What operating systems do you support?

The desktop application can be installed in OSX and Linux. [Windows is not yet supported](https://github.com/cypress-io/cypress/issues/74), although you can use Cypress if you install a Linux VM using something like VirtualBox or using a Docker image.

# {% fa fa-angle-right %} Do you support native mobile apps?

Cypress would never be able to run on a native mobile app, but would be able to run in a web view. In that mode, you'd see the commands display in a browser while you would drive the mobile device separately. Down the road we'll likely have first class support for this, but today it is not a current priority.

Currently you can control the {% url `cy.viewport()` viewport %} to test responsive, mobile views in a website or web application.

# {% fa fa-angle-right %} Do you support X language or X framework?

Any and all. Ruby, Node, C#, PHP - none of that matters. Cypress tests anything that runs in the context of a browser. It is backend, front-end, language and framework agnostic.

You'll write your tests in JavaScript, but beyond that Cypress works everywhere.

# {% fa fa-angle-right %} Will Cypress work in my CI provider?

Cypress works in any CI provider.

# {% fa fa-angle-right %} Does Cypress require me to change any of my existing code?

No. But if you're wanting to test parts of your application that are not easily testable, you'll want to refactor those situations (as you would for any testing).

# {% fa fa-angle-right %} If Cypress runs in the browser, doesn't that mean it's sandboxed?

Yes, technically; it's sandboxed and has to follow the same rules as every other browser. That's actually a good thing because it doesn't require a browser extension, and it naturally will work across all browsers (which enables cross-browser testing).

But Cypress is actually way beyond just a basic JavaScript application running in the browser. It's also a Desktop Application and communicates with backend web services.

All of these technologies together are coordinated and enable Cypress to work, which extends its capabilities far outside of the browser sandbox. Without these, Cypress would not work at all. For the vast majority of your web development, Cypress will work just fine, and already **does** work.

# {% fa fa-angle-right %} We use WebSockets, will Cypress work with that?

Yes.

<!-- # What are good use cases for Cypress? -->


<!-- # What are bad use cases for Cypress? -->

# {% fa fa-angle-right %} We have the craziest most insane authentication system ever, will Cypress work with that?

If you're using some crazy thumb-print, retinal-scan, time-based, key-changing, microphone audial decoding mechanism to log in your users, then no, Cypress won't work with that.  But seriously, Cypress is a **development** tool, which makes it easy to test your web applications. If your application is doing 100x things to make it extremely difficult to access, Cypress won't magically make it any easier.

Because Cypress is a development tool, you can always make your application more accessible while in your development environment. If you want, simply disable crazy steps in your authentication systems while you're in your testing environment. After all, that's why we have different environments! Normally you already have a development environment, a testing environment, a staging environment, and a production environment.  So simply expose the parts of your system you want accessible in each appropriate environment.

In doing so, Cypress may not be able to give you 100% coverage without you changing anything, but that's okay. Just use different tools to test the crazier, less accessible parts of your application, and let Cypress test the other 99%.

Just remember, Cypress won't make a non-testable application suddenly testable. It's on your shoulders to architect your code in an accessible manner.

# {% fa fa-angle-right %} Can I use Cypress to script user-actions on an external site like `gmail.com`?

No. There are already lots of tools to do that. Using Cypress to test against a 3rd party application is not supported. It **may** work but will defeat the purpose of why it was created. You use Cypress *while* you develop **your** application, it helps you write your tests.

# {% fa fa-angle-right %} Is there code coverage?

There is nothing currently built into Cypress to do this. Adding code coverage around end to end tests is much harder than unit and its possible it may not be feasible to do in a generic way. You can read in more detail about code coverage [here](https://github.com/cypress-io/cypress/issues/346).

<!-- # What kind of tests do I write in Cypress? -->


# {% fa fa-angle-right %} Does Cypress use Selenium / Webdriver?

No. In fact Cypress' architecture is very different from Selenium in a few critical ways:

- Cypress runs in the context of the browser. With Cypress it's much easier to accurately test the browser, but harder to talk to the outside work. In Selenium it's the exact opposite. Although Cypress has a few commands that give you access to the outside world - like {% url `cy.request()` request %} and {% url `cy.exec()` exec %}.

# {% fa fa-angle-right %} Are there driver bindings in my language?

Cypress does *not* utilize WebDriver for testing, so does not use or have any notion of driver bindings.

<!-- # Does Cypress have an equivalent to Selenium IDE? -->

# {% fa fa-angle-right %} Is Cypress open source?

We are working on open sourcing Cypress. You can read more [here](https://www.cypress.io/blog/2017/05/04/cypress-is-going-open-source/).

<!-- # How can I contribute to Cypress? -->

# {% fa fa-angle-right %} I found a bug! What do I do?

- Search existing [open issues](https://github.com/cypress-io/cypress/issues), it may already be reported!
- Update Cypress. Your issue may have [already been fixed](https://github.com/cypress-io/cypress/wiki/changelog).
- {% url 'Open an issue' https://github.com/cypress-io/cypress/issues/new %}. Your best chance of getting a bug looked at quickly is to provide a repository with a reproducible bug that can be cloned and run.
