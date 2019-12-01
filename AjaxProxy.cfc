<cfcomponent modifier="final" >

    <cfheader name="access-control-allow-credentials" value="false" />
    <cfheader name="access-control-allow-methods" value="GET, HEAD, POST, OPTIONS" />
    <cfheader name="access-control-allow-origin" value="*" />
    <!--- <cfheader name="access-control-expose-headers" value="*" /> --->
    <cfheader name="access-control-max-age" value="86400" />

    <cffunction name="call" returntype="struct" access="remote" returnformat="JSON" hint="Acts as a interface for frontend Javascript via ajax to call backend CFC methods, passing along argument data as well." >
        <cfargument name="asForm" type="boolean" required="false" default="false" hint="Pass as true if you are calling this CFC via POST instead of GET." />
        <cfargument name="controller" type="string" required="false" default="" hint="The name of the CFC you want to call." />
        <cfargument name="function" type="string" required="false" default="" hint="The name of the CFC you want to call." />
        <cfargument name="parameters" type="string" required="false" default="{}" hint="A structure of key/value pairs of arguments to the method you're calling." />
        <cfargument name="authKey" type="string" required="false" default="<:EMPTY:>" hint="A unique hash key that is checked against an internal validator. This exists to prevent people from using this proxy remotely without authorization." />

        <cfset var returnData = {RESPONSE_CODE: 0} />
        <cfset var deserializedParameters = {} />

        <cfif arguments.asForm >
            <cfif structIsEmpty(FORM) >
                <cfset application.events.log(data="Argument 'asForm' is defined, but the form-scope is empty", calledBy=getFunctionCalledName(), type="WARNING") />
                <cfreturn {RESPONSE_CODE: 1} />
            </cfif>

            <cfif structKeyExists(FORM, "controller") >
                <cfset arguments.controller = FORM.controller />
            </cfif>

            <cfif structKeyExists(FORM, "function") >
                <cfset arguments.function = FORM.function />
            </cfif>

            <cfif structKeyExists(FORM, "parameters") >
                <cfset arguments.parameters = FORM.parameters />
            </cfif>

            <cfif structKeyExists(FORM, "authKey") >
                <cfset arguments.authKey = FORM.authKey />
            </cfif>
        </cfif>

        <cftry>
            <cfset deserializedParameters = deserializeJSON(arguments.parameters) />

            <cfcatch>
                <cfheader statuscode="500" />
                <cfif structKeyExists(application, "events") AND isObject(application.events) >
                    <cfset application.events.log(data="Parameters couldn't be deserialized: #arguments.parameters#", calledBy=getFunctionCalledName(), type="WARNING") />
                </cfif>
                <cfreturn {RESPONSE_CODE: 2} />
            </cfcatch>
        </cftry>

        <cfif len(arguments.controller) IS 0 >
            <cfheader statuscode="500" />
            <cfif structKeyExists(application, "events") AND isObject(application.events) >
                <cfset application.events.log(data="Argument controller is empty", calledBy=getFunctionCalledName(), type="WARNING") />
            </cfif>
            <cfreturn {RESPONSE_CODE: 3} />
        </cfif>

        <cfif len(arguments.function) IS 0 >
            <cfheader statuscode="500" />
            <cfif structKeyExists(application, "events") AND isObject(application.events) >
                <cfset application.events.log(data="Argument function is empty", calledBy=getFunctionCalledName(), type="WARNING") />
            </cfif>
            <cfreturn {RESPONSE_CODE: 4} />
        </cfif>

        <cfif session.authKey IS NOT arguments.authKey >
            <cfheader statuscode="500" />
            <cfif structKeyExists(application, "events") AND isObject(application.events) >
                <cfset application.events.log(data="Auth key #arguments.authKey# is not valid (session.authKey: #session.authKey#)", calledBy=getFunctionCalledName(), type="WARNING") />
            </cfif>
            <cfreturn {RESPONSE_CODE: 5} />
        </cfif>

        <!--- The following 2 checks need to be coupled with a struct called allowedAJAXControllers in the application scope, where each index is the name of a CFC, and each key is an array of method names --->
        <cfif NOT structKeyExists(application.allowedAJAXControllers, arguments.controller) >
            <cfheader statuscode="500" />
            <cfif structKeyExists(application, "events") AND isObject(application.events) >
                <cfset application.events.log(data="Controller #arguments.controller# is not on the AJAX whitelist", calledBy=getFunctionCalledName(), type="WARNING") />
            </cfif>
            <cfreturn {RESPONSE_CODE: 6} />
        </cfif>

        <cfif NOT arrayFind(application.allowedAJAXControllers[arguments.controller], arguments.function) >
            <cfheader statuscode="500" />
            <cfif structKeyExists(application, "events") AND isObject(application.events) >
                <cfset application.events.log(data="Method #arguments.function# is not on the AJAX whitelist for controller #arguments.controller#", calledBy=getFunctionCalledName(), type="WARNING") />
            </cfif>
            <cfreturn {RESPONSE_CODE: 7} />
        </cfif>

        <cfif structKeyExists(application, "events") AND isObject(application.events) >
            <cfset application.events.log(data="Ajax call to #arguments.controller#.#arguments.function#() with parameters: #structKeyList(deserializedParameters)#", calledBy=getFunctionCalledName()) />
        </cfif>
        
        <cftry>
            <cfset returnData = invoke(application[arguments.controller], arguments.function, deserializedParameters) />
            
            <cfif returnData IS nullValue() >
                <cfset application.events.log(data="No return data from internal function/method call", calledBy=getFunctionCalledName()) />
                <cfreturn {RESPONSE_CODE: 8} />
            <cfelse>
                <cftry>
                    <cfset returnData = serializeJSON(returnData) />
                    
                    <cfcatch>
                        <cfset application.events.log(data="Return data from internal function/method call is NOT serializable", calledBy=getFunctionCalledName()) />
                        <cfreturn {RESPONSE_CODE: 9} />
                    </cfcatch>
                </cftry>
            </cfif>

            <cfcatch>
                <cfset application.events.log(data="Internal error", calledBy=getFunctionCalledName()) />
                <cfreturn {RESPONSE_CODE: 10} />
            </cfcatch>
        </cftry>

        <cfreturn returnData />
    </cffunction>

</cfcomponent>