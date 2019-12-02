component output="true" accessors="false" persistent="true" {
	
	property name="name"		type="string"	getter="true"	setter="false";
	property name="closure"		type="function"	getter="false"	setter="false";
	property name="parameters"	type="struct"	getter="false"	setter="false";

	public Task function init(required string name, required function procedure, struct parameters={}) {
		variables.closure = arguments.procedure;
		variables.parameters = arguments.parameters;
		variables.name = arguments.name;

		return this;
	}

	public void function run() {
		variables.closure(argumentCollection=variables.parameters);
	}
}

<!--- IMPORTANT ABOUT THREAD ARGUMENT SCOPING:

	ColdFusion makes a complete (deep) copy of all the attribute variables before passing them to the thread, so the values
	of the variables inside the thread are independent of the values of any corresponding variables in other threads,
	including the page thread. Thus, the values passed to threads are thread safe because the attribute values cannot be
	changed by any other thread.

--->