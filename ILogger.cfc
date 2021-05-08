<cfinterface>

    <cffunction access="public" name="Information" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />
    </cffunction>

    <cffunction access="public" name="Warning" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />
    </cffunction>

    <cffunction access="public" name="Error" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />
    </cffunction>

</cfinterface>