<cfcomponent output="false" modifier="final" >

    <!--- PROPERTIES --->

    <cfset variables.absolutePathToLogFolder = "" />
    <cfset variables.eventTypes = ["CRITICAL","INFO","WARNING"] />
    <cfset variables.debugMode = false />
    <cfset variables.pathNormalizer = nullValue() />
    <cfset variables.charset = "utf-8" />

    <!--- PUBLIC --->

    <cffunction name="init" returntype="EventManager" access="public" >
        <cfargument name="absolutePathToLogFolder" type="string" required="true" />
        <cfargument name="pathNormalizer" type="function" required="true" />
        <cfargument name="charset" type="string" required="false" />

        <cfif structKeyExists(arguments, "charset") >
            <cfset variables.charset = arguments.charset />
        </cfif>

        <cfset variables.pathNormalizer = arguments.pathNormalizer />
        <cfset variables.absolutePathToLogFolder = variables.pathNormalizer(path=(arguments.absolutePathToLogFolder & "/")) />

        <cfif NOT directoryExists(variables.absolutePathToLogFolder) >
            <cfthrow message="Error initializing EventManager" detail="The folder from argument 'absolutePathToLogFolder' does not exist (#variables.absolutePathToLogFolder#)" />
        </cfif>

        <cfreturn this />
    </cffunction>

    <cffunction name="log" returntype="void" access="public" output="true" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="type" type="string" required="false" default="INFO" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />
        <cfargument name="eventCode" type="string" required="false" default="UNKNOWN" />

        <cfset var logEntry = "" />

        <cfif arrayFind(variables.eventTypes, arguments.type) IS 0 >
            <cfthrow message="Error triggering event" detail="Argument 'type' is invalid: #arguments.type# | Valid types are: #arrayToList(variables.eventTypes)#" />
        </cfif>

        <!--- Simple data types are just output as text to a txt-file --->
        <cfif isSimpleValue(arguments.data) >

            <cfset variables.logSimple(
                type=arguments.type,
                data=arguments.data,
                calledBy=arguments.calledBy,
                eventCode=arguments.eventCode
            ) />
            <cfreturn/>
        </cfif>
        
        <!--- Complex data types are dumped and logged as HTML --->
        <cfset variables.logComplex(
            type=arguments.type,
            data=arguments.data,
            calledBy=arguments.calledBy,
            eventCode=arguments.eventCode
        ) />
    </cffunction>

    <!--- PRIVATE --->

    <cffunction name="logSimple" returntype="void" access="private" >
        <cfargument name="type" type="string" required="false" default="INFO" />
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />
        <cfargument name="eventCode" type="string" required="false" default="UNKNOWN" />

        <cfset var logEntry = "#variables.getOutputPrependData(calledBy=arguments.calledBy, eventCode=arguments.eventCode)# - [#arguments.type#]: #trim(data)#" />
        <cfset variables.writeToDisk(logEntry=logEntry, fileExtension="txt") />

        <cfif variables.debugMode >
            <cfset variables.writeToScreen(
                logEntry=logEntry,
                type=arguments.type
            ) />
        </cfif>
    </cffunction>

    <cffunction name="logComplex" returntype="void" access="private" >
        <cfargument name="type" type="string" required="false" default="INFO" />
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />
        <cfargument name="eventCode" type="string" required="false" default="UNKNOWN" />

        <cfset var logEntry = "" />

        <cfsavecontent variable="logEntry" >
        <cfoutput>
        
        <section class="logEntry" >
            <h1 style="#trim(variables.getHTMLStylingForLogType(type=arguments.type))#" >#trim(variables.getOutputPrependData(calledBy=arguments.calledBy, eventCode=arguments.eventCode))#:</h1>
            <p>
                <cfdump var=#arguments.data# />
            </p>
        </section>
        <hr/>
            
        </cfoutput>
        </cfsavecontent>

        <cfset logEntry = reReplace(logEntry, "<script[\s\S\n]+?/script>", "", "ALL") />
        <!--- <cfset arguments.data = reReplace(arguments.data, " +", " ", "ALL") /> --->

        <cfset variables.writeToDisk(logEntry=trim(logEntry), fileExtension="html") />
    </cffunction>

    <cffunction name="writeToDisk" returntype="void" access="private" >
        <cfargument name="logEntry" type="string" required="true" />
        <cfargument name="fileExtension" type="string" required="false" default="txt" />

        <cfset var fullFilePathAndName = variables.absolutePathToLogFolder & variables.getLogFileName() & "." & arguments.fileExtension />

        <cfif fileExists(fullFilePathAndName) >
                <cffile action="append" output=#arguments.logEntry# file=#fullFilePathAndName# charset=#variables.charset# addnewline="true" />
            <cfreturn/>
        </cfif>

        <cffile action="write" output=#arguments.logEntry# file=#fullFilePathAndName# charset=#variables.charset# addnewline="true" />
    </cffunction>

    <cffunction name="writeToScreen" returntype="string" access="private" output="true" >
        <cfargument name="logEntry" type="string" required="false" default="INFO" />
        <cfargument name="type" type="string" required="false" default="INFO" />

        <cfoutput><p class="EventLogEntry" style="#trim(variables.getHTMLStylingForLogType(type=arguments.type))#" >&nbsp;#htmlEditFormat(arguments.logEntry)#&nbsp;</p><br/></cfoutput>
    </cffunction>

    <cffunction name="getLogFileName" returntype="string" access="private" >
        <cfset var logFileName = "EventLog_" & lsDateFormat(now(), "yyyy_mm_dd") />
        <cfreturn logFileName />
    </cffunction>

    <cffunction name="getHTMLStylingForLogType" returntype="string" access="private" >
        <cfargument name="type" type="string" required="false" default="INFO" />

        <cfset var HTMLStyleString = "background-color: green; color: white;" />

        <cfswitch expression=#arguments.type# >
            <cfcase value="WARNING" >
                <cfset HTMLStyleString = "background-color: orange; color: white;" />
            </cfcase>

            <cfcase value="CRITICAL" >
                <cfset HTMLStyleString = "background-color: red; color: white;" />
            </cfcase>
        </cfswitch>

        <cfreturn HTMLStyleString />
    </cffunction>

    <cffunction name="getOutputPrependData" returntype="string" access="private" >
        <cfargument name="calledBy" type="string" required="false" default="NIL" />
        <cfargument name="eventCode" type="string" required="false" default="NIL" />

        <cfreturn "#LSDateTimeFormat(now(), "[dd/mm/yyyy - HH:nn:ss]")# - [#(len(arguments.calledBy) GT 0 ? arguments.calledBy : "NIL")#] - [#(len(arguments.eventCode) GT 0 ? arguments.eventCode : "NIL")#]" />
    </cffunction>
</cfcomponent>