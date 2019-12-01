component output="true" accessors="false" persistent="true" {
	
	property name="threadMasterList"		type="array"	getter="false"	setter="false";
	property name="threadThrottleWatchList"	type="array"	getter="false"	setter="false";
	property name="maxThreads"				type="numeric"	getter="true"	setter="false";
	property name="joinTimeout"				type="numeric"	getter="true"	setter="false";
	property name="throttleJoinTimeout"		type="numeric"	getter="true"	setter="false";
	property name="eventManager"			type="any"		getter="false"	setter="false";
	property name="taskList"				type="array"	getter="false"	setter="false";

	public TaskManager function init(numeric maxThreads=0, numeric joinTimeout=0, numeric throttleJoinTimeout=0, EventManager eventManager) {

		// Property initialization
		variables.threadMasterList = [];
		variables.threadThrottleWatchList = [];
		variables.maxThreads = 3;
		variables.joinTimeout = 120000;
		variables.throttleJoinTimeout = 120000;
		variables.eventManager = nullValue();
		variables.taskList = [];

		if (arguments.maxThreads > 0) variables.maxThreads = arguments.maxThreads;
		if (arguments.joinTimeout > 0) variables.joinTimeout = arguments.joinTimeout;
		if (arguments.throttleJoinTimeout > 0) variables.throttleJoinTimeout = arguments.throttleJoinTimeout;
		if (structKeyExists(arguments, "eventManager")) variables.eventManager = arguments.eventManager;

		return this;
	}

	public void function runAll(required array tasks, function callback) {
		if (arrayIsEmpty(arguments.tasks)) return;

		variables.taskList = arguments.tasks;
		if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Executing #arrayLen(variables.taskList)# tasks", calledBy=getFunctionCalledName());

		var currentTaskName;
		var index;

		for(index = 1; index <= arrayLen(variables.taskList); index++) {

			currentTaskName = variables.taskList[index].getName();

			if (arrayFind(variables.threadMasterList, currentTaskName) GT 0 ) {
				if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Duplicate task name: #currentTaskName#", calledBy=getFunctionCalledName(), type="CRITICAL");
				continue;
			}

			thread name=currentTaskName action="run" index=index {
				try {
					variables.taskList[index].run();
				}
				catch(error) {
					variables.onFailedThread(name=thread.name, error=error);
				}
			}

			arrayAppend(variables.threadMasterList, currentTaskName);
			arrayAppend(variables.threadThrottleWatchList, currentTaskName);

			if (arrayLen(variables.threadThrottleWatchList) EQ variables.maxThreads) {
				if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Max threads reached (#variables.maxThreads#), waiting (#variables.throttleJoinTimeout# ms max)", calledBy=getFunctionCalledName());
				thread action="join" name=arrayToList(variables.threadThrottleWatchList) timeout=variables.throttleJoinTimeout;
				
				if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Resuming", calledBy=getFunctionCalledName());
				arrayClear(variables.threadThrottleWatchList);
			}
		}

		if (structKeyExists(arguments, "callback"))
			variables.onAllFinished(callback=arguments.callback);
		else 
			variables.onAllFinished();
	}

	private void function onFailedThread(required string name, required struct error) {
		if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Thread '#arguments.name#' failed", calledBy="runAll", type="CRITICAL");
		if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data=arguments.error, calledBy=arguments.name, type="CRITICAL");
	}

	private void function onAllFinished(function callback) {
		var threadName;
		var currentThread;
		var callbackArgument = {};

		thread action="join" name=arrayToList(variables.threadMasterList) timeout=variables.joinTimeout;

		for(threadName in variables.threadMasterList) {
			currentThread = cfthread[threadName];

			if (currentThread.status EQ "RUNNING" OR currentThread.status EQ "WAITING") {
				thread action="terminate" name=threadName priority="HIGH";
				if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Long running thread terminated: #threadName#", calledBy=getFunctionCalledName(), type="WARNING");
				continue;
			}
			
			if (structKeyExists(arguments, "callback") AND len(currentThread.output) > 0)
				callbackArgument[threadName] = currentThread.output;

			if (structKeyExists(variables, "eventManager") AND currentThread.status EQ "COMPLETED")
				variables.eventManager.log(data="Thread '#threadName#' finished without errors", calledBy=getFunctionCalledName());
		}

		arrayClear(variables.taskList);
		arrayClear(variables.threadMasterList);
		arrayClear(variables.threadThrottleWatchList);

		if (structKeyExists(variables, "eventManager")) variables.eventManager.log(data="Finished executing all tasks", calledBy=getFunctionCalledName());

		if (structKeyExists(arguments, "callback"))
			arguments.callbackArgument(callbackArgument);
	}
}