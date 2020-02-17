<cfcomponent persistent="true" accessors="false" modifier="final" >

	<cfheader name="access-control-allow-credentials" value="true" />
	<cfheader name="access-control-allow-methods" value="GET, HEAD, POST, OPTIONS" />
	<cfheader name="access-control-allow-origin" value="*" />
	<cfheader name="access-control-max-age" value="86400" />

	<cffunction name="call" returntype="struct" returnformat="JSON" access="remote" hint="Acts as a interface for frontend Javascript via ajax to call backend CFC methods, passing along argument data as well." >
		<cfargument name="controller" type="string" required="false" default="" hint="The name of the CFC you want to call." />
		<cfargument name="function" type="string" required="false" default="" hint="The name of the CFC you want to call." />
		<cfargument name="parameters" type="string" required="false" default="{}" hint="A structure of key/value pairs of arguments to the method you're calling." />
		<cfargument name="authKey" type="string" required="false" default="<:EMPTY:>" hint="A unique hash key that is checked against an internal validator. This exists to prevent people from using this proxy remotely without authorization." />

		<cfset var returnData = {RESPONSE_CODE: 0, RESPONSE: nullValue()} />
        <cfset var deserializedParameters = {} />

		<cftry>
            <cfset deserializedParameters = deserializeJSON(arguments.parameters) />
            <!--- Include a 'sessionHandle'-key of any value in argument 'parameters' and the current session will be passed to the invoked method --->
            <cfif structKeyExists(deserializedParameters, "sessionHandle") >
                <cfset deserializedParameters["sessionHandle"] = SESSION />
            </cfif>

			<cfcatch>
				<cfreturn {RESPONSE_CODE: 1} />
			</cfcatch>
        </cftry>
        
        <cftry>
            <!--- Include an 'uploadFiles'-key of any value in argument 'parameters' and the files on the form will be uploaded. The result of the upload will be put in uploadFiles-key in the parameters --->
            <cfif structKeyExists(deserializedParameters, "uploadFiles") AND isArray(deserializedParameters.uploadFiles, 1) >
                <cfset var uploadedFiles = {} />

                <cfloop array=#deserializedParameters.uploadFiles# index="currentFormFileField" >
                    <cfset uploadedFiles[currentFormFileField] = fileUpload(
                        destination=application.mapping.tempFiles,
                        filefield=currentFormFileField,
                        nameConflict="makeunique"
                    ) />
                </cfloop>

                <cfset deserializedParameters.uploadFiles = uploadedFiles />
            </cfif>

            <cfcatch>
                <cfreturn {RESPONSE_CODE: 2} />
            </cfcatch>
        </cftry>

		<cfif len(arguments.controller) IS 0 >
			<cfreturn {RESPONSE_CODE: 3} />
		</cfif>

		<cfif len(arguments.function) IS 0 >
			<cfreturn {RESPONSE_CODE: 4} />
		</cfif>

        <cfif   NOT structKeyExists(session, "ajaxAuthKey")
                OR (structKeyExists(session, "ajaxAuthKey") AND session.ajaxAuthKey IS NOT arguments.authKey) >

			<cfreturn {RESPONSE_CODE: 5} />
		</cfif>

		<!--- The following 2 checks need to be coupled with a struct called allowedAJAXControllers in the application scope, where each index is the name of a CFC, and each key is an array of method names --->
		<cfif NOT structKeyExists(application.allowedAJAXControllers, arguments.controller) >
			<cfreturn {RESPONSE_CODE: 6} />
		</cfif>

		<cfif NOT arrayFind(application.allowedAJAXControllers[arguments.controller], arguments.function) >
			<cfreturn {RESPONSE_CODE: 7} />
		</cfif>
		
        <cftry>
            <!--- If your controllers live somewhere else change this line to reflect that --->
            <!--- Whatever is returned by the invoked method is expected to be able to be serialized --->
            <cfset var controllerResponse = invoke(application[arguments.controller], arguments.function, deserializedParameters) />
			
            <!--- The invoked method is void so we return a magic number indicating that the invoke succeeded but there's no return data --->
            <cfif NOT isDefined("controllerResponse") OR isNull(controllerResponse) >
				<cfreturn {RESPONSE_CODE: 42} />
            </cfif>
            
            <cfif NOT isSimpleValue(controllerResponse) >
                <cfset serializeJSON(controllerResponse) />
            </cfif>

            <cfcatch>
                <!--- Error upon invoking the method or serializing the response. Put some sort of logging in here for the catch if you want to know what's going on --->
                <cfdump var=#cfcatch# format="html" output="#application.mapping.logs#/InternalError.html" />
				<cfreturn {RESPONSE_CODE: 8} />
			</cfcatch>
		</cftry>

        <cfif isStruct(controllerResponse) >
            <cfset returnData["RESPONSE"] = controllerResponse />
            <cfreturn returnData />
        </cfif>
        
        <cfreturn {RESPONSE_CODE: 9} />
	</cffunction>

</cfcomponent>