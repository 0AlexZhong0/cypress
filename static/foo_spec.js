

describe("playground", function() {
  return it("is true", function() {
    cy.viewport(500, 500)
    cy.visit("test.html")

    return expect(true).to.be["true"];
  });
});
