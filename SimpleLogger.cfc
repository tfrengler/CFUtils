<cfcomponent output="false" modifier="final" accessors="false" implements="ILogger" >

    <!--- PROPERTIES --->

    <cfset variables.AvailableCharsets = ["utf-8","iso-8859-1","windows-1252","us-ascii","shift_jis","iso-2022-jp","euc-jp","euc-kr","big5","euc-cn","utf-16"] />
    <cfset variables.ValidLogTypes = ["txt", "html"] />

    <cfset variables.AbsolutePathToLogFolder = 0 />
    <cfset variables.Charset = 0 />
    <cfset variables.LogType = 0 />
    <cfset variables.GenerateLogFileName = function() { return "#LSDateFormat(now(), "yyyy_mm_dd")#.#variables.logType#"; } />

    <!--- PUBLIC --->

    <cffunction name="init" returntype="SimpleLogger" access="public" output="false" >
        <cfargument name="absolutePathToLogFolder" type="string" required="true" />
        <cfargument name="type" type="string" required="true" />
        <cfargument name="charset" type="string" required="false" default="UTF-8" />
        <cfscript>

        if (arrayFindNoCase(variables.ValidLogTypes, arguments.type) == 0)
            throw(message="Error initializing LogManager", detail="Argument 'type' is not valid: #arguments.type# | Valid types are: #arrayToList(variables.availableCharsets)#")

        if (arrayFindNoCase(variables.availableCharsets, arguments.charset) == 0)
            throw(message="Error initializing LogManager", detail="The charset is not supported: #arguments.charset# | Supported charsets are: #arrayToList(variables.availableCharsets)#")

        if (!directoryExists(arguments.absolutePathToLogFolder))
            throw(message="Error initializing LogManager", detail="The folder from argument 'absolutePathToLogFolder' does not exist (#arguments.absolutePathToLogFolder#)")

        variables.AbsolutePathToLogFolder = arguments.absolutePathToLogFolder;
        variables.Charset = arguments.charset;
        variables.LogType = lCase(arguments.type);

        return this;

        </cfscript>
    </cffunction>

    <cffunction access="public" name="Information" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />

        <cfset DoLogEntry(arguments.data, "INFO", arguments.calledBy) />
    </cffunction>

    <cffunction access="public" name="Warning" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />

        <cfset DoLogEntry(arguments.data, "WARNING", arguments.calledBy) />
    </cffunction>

    <cffunction access="public" name="Error" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="calledBy" type="string" required="false" default="UNKNOWN" />

        <cfset DoLogEntry(arguments.data, "ERROR", arguments.calledBy) />
    </cffunction>

    <!--- PRIVATE --->

    <cffunction access="private" name="DoLogEntry" returntype="void" output="false" >
        <cfargument name="data" type="any" required="true" />
        <cfargument name="type" type="string" required="true" />
        <cfargument name="calledBy" type="string" required="true" />
        <cfscript>

        if (!IsSimpleValue(arguments.data))
        {
            arguments.data = "Attempted to log a complex value which is not supported";
            arguments.type = "WARNING";
        }

        WriteToDisk(
            GenerateLogEntry(arguments.data, arguments.type, arguments.calledBy),
            variables.logType
        );
        </cfscript>
    </cffunction>

    <cffunction access="private" name="WriteToDisk" returntype="void" output="false">
        <cfargument name="logEntry" type="string" required="true" />

        <cfset var FullFilePathAndName = variables.absolutePathToLogFolder & GenerateLogFileName() />

        <cfif fileExists(FullFilePathAndName) >
            <cffile action="append" file=#FullFilePathAndName# output=#arguments.logEntry# charset=#variables.charset# />
            <cfreturn />
        </cfif>

        <cffile action="write" file=#FullFilePathAndName# output=#arguments.logEntry# charset=#variables.charset# />
        <cfset fileSetAccessMode(fullFilePathAndName, "774") />
    </cffunction>

    <cffunction access="private" name="getHTMLStylingForLogType" returntype="string" output="false">
        <cfargument name="type" type="string" required="true" />
        <cfscript>

        switch(arguments.type)
        {
            case "WARNING":
                return "background-color: orange; color: white;margin-bottom:0.2rem;";

            case "ERROR":
                return "background-color: red; color: white;margin-bottom:0.2rem;";

            <!--- INFO --->
            default:
                return "background-color: green; color: white;margin-bottom:0.2rem;";
        }
        </cfscript>
    </cffunction>

    <cffunction access="private" name="GenerateLogEntry" returntype="string" output="false">
        <cfargument name="data" type="string" required="true" />
        <cfargument name="type" type="string" required="true" />
        <cfargument name="calledBy" type="string" required="true" />
        <cfscript>

        var ReturnData = "#LSDateTimeFormat(now(), "[dd/mm/yyyy - HH:nn:ss]")# - [#arguments.type#] - [#arguments.calledBy#]: #arguments.data#";
        if (variables.logType == "txt") return ReturnData;

        return "<div data-name='LogEntry' style='#getHTMLStylingForLogType(arguments.type)#'>#ReturnData#</div>";
        </cfscript>
    </cffunction>
</cfcomponent>