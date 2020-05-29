<cfcomponent displayname="PoolObject" output="false" accessors="false" persistent="true">

    <cfproperty name="id"               type="numeric"  getter="false" setter="false" />
    <cfproperty name="releasePointer"   type="Function" getter="false" setter="false" />
    <cfproperty name="data"             type="any"      getter="true"  setter="false" />

    <cffunction name="init" access="public" returntype="PoolObject" >
        <cfargument name="id"               type="numeric"  required="true" >
        <cfargument name="data"             type="any"      required="true" >
        <cfargument name="releasePointer"   type="Function" required="true" >

        <cfset variables.id = arguments.id />
        <cfset variables.data = arguments.data />
        <cfset variables.releasePointer = arguments.releasePointer />

        <cfreturn this />
    </cffunction>

    <cffunction name="release" access="public" returntype="void" >
        <cfset variables.driver = null />
        <cfset variables.releasePointer(variables.id) />
    </cffunction>
</cfcomponent>