---
title: url
comments: true
---

Get the current URL.

{% note info %}
This is an alias of [`cy.location.href`](https://on.cypress.io/api/location)
{% endnote %}

# Syntax

```javascript
cy.url()
cy.url(options)
```

## Usage

`cy.url()` cannot be chained off any other cy commands, so should be chained off of `cy` for clarity.

**{% fa fa-check-circle green %} Valid Usage**

```javascript
cy.url()    // Get url
```

## Arguments

**{% fa fa-angle-right %} options** ***(Object)***

Pass in an options object to change the default behavior of `cy.url()`.

**cy.hash( *options* )**

Option | Default | Notes
--- | --- | ---
`log` | `true` | Whether to display command in Command Log

## Yields

`cy.url()` yields the current URL as a string.

## Timeout

# Examples

## Url

**Assert the URL is `http://localhost:8000/users/1/edit`**

```javascript
// clicking the anchor causes the browser to follow the link
cy.get('#user-edit a').click()
cy.url().should('eq', 'http://localhost:8000/users/1/edit') // => true
```

**Url is a shortcut for `cy.location().href`**

`cy.url()` uses `href` under the hood.

```javascript
cy.url()                  // these yield the same string
cy.location().its('href') // these yield the same string
```

**Url versus href**

Given the remote URL, `http://localhost:8000/index.html`, all 3 of these assertions are the same.

```javascript
cy.location().its('href').should('eq', 'http://localhost:8000/index.html')

cy.location().invoke('toString').should('eq', 'http://localhost:8000/index.html')

cy.url().should('eq', 'http://localhost:8000/index.html')
```

`href` and `toString` come from the `window.location` spec.

But you may be wondering where the `url` property comes from.  Per the `window.location` spec, there actually isn't a `url` property on the `location` object.

`cy.url()` exists because it's what most developers naturally assume would return them the full current URL.  We almost never refer to the URL as an `href`.

# Command Log

**Assert that the url contains "#users/new"**

```javascript
cy.url().should('contain', '#users/new')
```

The commands above will display in the command log as:

<img width="583" alt="screen shot 2015-11-29 at 1 42 40 pm" src="https://cloud.githubusercontent.com/assets/1271364/11459196/20645888-969f-11e5-973a-6a4a98339b15.png">

When clicking on `url` within the command log, the console outputs the following:

<img width="440" alt="screen shot 2015-11-29 at 1 42 52 pm" src="https://cloud.githubusercontent.com/assets/1271364/11459197/229e2552-969f-11e5-80a9-eeaf3221a178.png">

# See also

- {% url `cy.document()` document %}
- {% url `cy.hash()` hash %}
- {% url `cy.location()` location %}
- {% url `cy.window()` window %}
