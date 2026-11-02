component output=false hint="Fixture-only mail capture. Never connects to a mail transport." {
  public any function init(string status="SUBMITTED") {
    variables.calls = [];
    variables.submissions = createObject("java","java.util.concurrent.atomic.AtomicInteger").init(javaCast("int",0));
    variables.lockName = "ArrivalCapture" & replace(createUUID(),"-","","all");
    variables.status = arguments.status;
    variables.byRecipient = {};
    variables.entered = createObject("java","java.util.concurrent.CountDownLatch").init(javaCast("int",1));
    variables.release = createObject("java","java.util.concurrent.CountDownLatch").init(javaCast("int",1));
    variables.hold = false;
    return this;
  }

  public void function setRecipientStatus(required string address,required string status) {
    variables.byRecipient[lCase(arguments.address)] = arguments.status;
  }

  public void function holdSubmission() {
    variables.hold = true;
  }

  public boolean function awaitSubmission() {
    return variables.entered.await(javaCast("long",12),createObject("java","java.util.concurrent.TimeUnit").SECONDS);
  }

  public void function releaseSubmission() {
    variables.release.countDown();
  }

  public struct function submit(required string address,required struct message) {
    if (!reFindNoCase("^[A-Z0-9_.+-]+@example\.test$",arguments.address)) {
      throw(type="ArrivalCapture.UnexpectedRecipient",message="Capture accepts synthetic test addresses only.");
    }
    variables.submissions.incrementAndGet();
    lock name=variables.lockName type="exclusive" timeout=5 {
      arrayAppend(variables.calls,{address=arguments.address,message=duplicate(arguments.message)});
    }
    variables.entered.countDown();
    if (variables.hold && !variables.release.await(javaCast("long",15),createObject("java","java.util.concurrent.TimeUnit").SECONDS)) {
      throw(type="ArrivalCapture.Timeout",message="Synthetic handoff timed out.");
    }
    var status = variables.byRecipient[lCase(arguments.address)] ?: variables.status;
    if (status=="THROW") throw(type="ArrivalCapture.Unknown",message="Synthetic interruption during handoff.");
    return {status=status,reason="TEST_" & status};
  }

  public numeric function submittedCount() {
    return variables.submissions.get();
  }

  public array function calls() {
    lock name=variables.lockName type="readonly" timeout=5 {
      return duplicate(variables.calls);
    }
  }
}
