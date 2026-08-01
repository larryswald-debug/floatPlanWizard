component output="false" {
  variables.pdfPath = "";
  variables.shouldSucceed = true;

  public any function init(required string pdfPath, boolean shouldSucceed=true) output=false {
    variables.pdfPath = arguments.pdfPath;
    variables.shouldSucceed = arguments.shouldSucceed;
    return this;
  }

  public any function createPDF(required numeric floatPlanId, required numeric userId) output=false {
    return variables.shouldSucceed ? listLast(variables.pdfPath, "/\") : "";
  }

  public string function getPdfPath(required string fileName) output=false {
    return variables.pdfPath;
  }
}
