describe "Login", ->
  beforeEach ->
    cy.fixture("user").as("user")

    cy.visitIndex().then (win) ->
      { start, @ipc } = win.App

      cy.stub(@ipc, "onMenuClicked")
      cy.stub(@ipc, "onFocusTests")
      cy.stub(@ipc, "getOptions").resolves({})
      cy.stub(@ipc, "getCurrentUser").resolves(null)
      cy.stub(@ipc, "updaterCheck").resolves(false)
      cy.stub(@ipc, "getProjects").resolves([])
      cy.stub(@ipc, "getProjectStatuses").resolves([])
      cy.stub(@ipc, "openProject").resolves(@config)
      cy.stub(@ipc, "getSpecs").yields(null, @specs)
      cy.stub(@ipc, "externalOpen")
      cy.stub(@ipc, "clearGithubCookies")
      cy.stub(@ipc, "logOut").resolves()

      @openWindow = @util.deferred()
      cy.stub(@ipc, "windowOpen").returns(@openWindow.promise)

      @login = @util.deferred()
      cy.stub(@ipc, "logIn").returns(@login.promise)

      start()
      cy.contains("Log In").click()

  it "has Github Login button", ->
    cy.get(".login").contains("button", "Log In with GitHub")

  it "opens dashboard on clicking 'Cypress Dashboard'", ->
    cy.contains("Cypress Dashboard").click().then ->
      expect(@ipc.externalOpen).to.be.calledWith("https://on.cypress.io/dashboard")

  it "displays help link", ->
    cy.get(".login").contains("a", "Need help?")

  it "opens link to login docs on click of help link", ->
    cy.get(".login").contains("a", "Need help?").click().then ->
      expect(@ipc.externalOpen).to.be.calledWith("https://on.cypress.io/logging-in")

  describe "click 'Log In with GitHub'", ->
    beforeEach ->
      cy
        .get(".login")
          .contains("button", "Log In with GitHub").as("loginBtn")

    it "triggers ipc 'window:open' on click", ->
      cy
        .get("@loginBtn").click().then ->
          expect(@ipc.windowOpen).to.be.calledWithExactly({
            position: "center"
            focus: true
            width: 1000
            height: 635
            preload: false
            title: "Login"
            type: "GITHUB_LOGIN"
          })

    it "disables login button", ->
      cy.get("@loginBtn").click().should("be.disabled")

    context "on 'window:open' ipc response", ->
      beforeEach ->
        cy.get("@loginBtn").click().then ->
          @openWindow.resolve("code-123")

      it "triggers ipc 'log:in'", ->
        cy.then ->
          expect(@ipc.logIn).to.be.calledWith("code-123")

      it "displays spinner with 'Logging in...' and disables button", ->
        cy.contains("Logging in...").should("be.disabled")

      describe "on ipc log:in success", ->
        beforeEach ->
          @login.resolve(@user)

        it "goes to previous view", ->
          cy.shouldBeOnIntro()

        it "displays username in UI", ->
          cy
            .get("nav a").should ($a) ->
              expect($a).to.contain(@user.name)

        it "closes modal", ->
          cy.get(".modal").should("not.be.visible")

        context "log out", ->
          it "displays login button on logout", ->
            cy
              .get("nav a").contains("Jane").click()
            cy
              .contains("Log Out").click()
              .get(".nav").contains("Log In")

          it "calls clear:github:cookies", ->
            cy
              .get("nav a").contains("Jane").click()
            cy
              .contains("Log Out").click().then ->
                expect(@ipc.clearGithubCookies).to.be.called

          it "calls log:out", ->
            cy
              .get("nav a").contains("Jane").click()
            cy
              .contains("Log Out").click().then ->
                expect(@ipc.logOut).to.be.called

          it "has login button enabled when returning to login after logout", ->
            cy.get("nav a").contains("Jane").click()
            cy.contains("Log Out").click()
            cy.contains("Log In").click()
            cy.get(".login button").eq(1)
              .should("not.be.disabled")
              .invoke("text")
              .should("include", "Log In with GitHub")

      describe "on ipc 'log:in' error", ->
        beforeEach ->
          @login.reject({name: "foo", message: "There's an error"})

        it "displays error in ui", ->
          cy
            .get(".alert-danger")
              .should("be.visible")
              .contains("There's an error")

        it "login button should be enabled", ->
          cy
            .get("@loginBtn").should("not.be.disabled")

      describe "on ipc 'log:in' unauthorized error", ->
        beforeEach ->
          @login.reject({
            error: "Your email: 'foo@bar.com' has not been authorized."
            message: "Your email: 'foo@bar.com' has not been authorized."
            name: "StatusCodeError"
            statusCode: 401
          })

        it "displays error in ui", ->
          cy
            .get(".alert-danger")
              .should("be.visible")
              .contains("Your email: 'foo@bar.com' has not been authorized")

        it "displays authorized help link", ->
          cy
            .contains("a", "Why am I not authorized?")

        it "opens link to docs on click of help link", ->
          cy
            .contains("a", "Why am I not authorized?").click().then ->
              expect(@ipc.externalOpen).to.be.calledWith("https://on.cypress.io/email-not-authorized")

        it "login button should be enabled", ->
          cy
            .get("@loginBtn").should("not.be.disabled")
