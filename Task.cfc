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