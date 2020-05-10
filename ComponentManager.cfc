    <cfcomponent displayname="ComponentManager" persistent="true" output="false" hint="" >

    <cfproperty name="componentsRootFolder" type="string"   getter="false" setters="false" />
    <cfproperty name="manifestsFolder"      type="string"   getter="false" setters="false" />
    <cfproperty name="componentMapping"     type="string"   getter="false" setters="false" />
    <cfproperty name="componentManifests"   type="array"    getter="false" setters="false" />

    <!--- CF data types: ["void","string","numeric","date","boolean","array","struct","query","guid","xml","any","binary"] /> --->

    <cffunction name="GetInternals" access="public" returntype="struct" hint="" >
        <cfreturn {
            componentsRootFolder: variables.componentsRootFolder,
            manifestsFolder: variables.manifestsFolder,
            componentMapping: variables.componentMapping,
            componentManifests: variables.componentManifests
        } />
    </cffunction>

    <cffunction name="GetComponentManifest" access="public" returntype="struct" hint="Returns a manifest for a component stored in the manager" >
        <cfargument name="componentName" type="string" required="true" default="" hint="" />

        <cfscript>
            var ComponentName = arguments.componentName;
            var ComponentIndex = arrayFind(variables.componentManifests, (required struct ComponentManifest)=> {
                return arguments.ComponentManifest.name EQ ComponentName
            });

            if (ComponentIndex GT 0)
                return variables.componentManifests[ComponentIndex];
            else
                return {};
        </cfscript>
    </cffunction>

    <cffunction name="BuildComponentManifest" access="public" returntype="struct" hint="" >
        <cfargument name="dottedPath"   type="string"   required="true" hint="" />
        <cfargument name="saveToDisk"   type="boolean"  required="true" hint="" />

        <!--- 
            {
                Name:           string
                DisplayName:    string
                DottedPath:     string
                AbsolutePath:   string
                Extends:        string
                Hint:           string
                Output:         boolean
                CreatedOn:      string (ODBC)
                Methods: {
                    Public: {}
                    Private: {}
                }
            }

            METHOD:
            {
                Name            | string
                Signature       | string
                Hint            | string
                Output          | boolean
                ReturnType      | string
                ReturnFormat    | string
                Arguments: {
                    Optional: {}
                    Required: {}
                }
            }

            ARGUMENT:
            {
                Name    | string
                Type    | string
                Default | boolean
                Hint    | string
            }
        --->

        <cfscript>
        var ReturnData = {Data: null, Errors: []};

        try {
            var ComponentMetadata = getComponentMetadata(arguments.dottedPath);
        }
        catch(any error) {
            ReturnData.Errors.append("Error building component manifest - unable to get metadata for #arguments.dottedPath#: #error.message#");
            return ReturnData;
        }

        var ComponentStructure = {
            Name: listLast(ComponentMetadata.fullName, "."), //Obviously this will not account for people who name their CFC's with dots in the filename...
            DisplayName: structKeyExists(ComponentMetadata, "displayName") ? ComponentMetadata.displayName : "",
            DottedPath: ComponentMetadata.fullName,
            AbsolutePath: ComponentMetadata.path,
            Extends: reFind("Component.cfc$", ComponentMetadata.extends.path) GT 0 ? "" : ComponentMetadata.extends.fullName, // All components extend Component.cfc from Lucee/ACF as their base class
            Hint: structKeyExists(ComponentMetadata, "hint") ? ComponentMetadata.hint : "",
            Output: structKeyExists(ComponentMetadata, "output") ? ComponentMetadata.output : false, //Does it default to true or false...?
            CreatedOn: createODBCDateTime(now()),
            Methods: {}
        };

        if (structKeyExists(ComponentMetadata, "functions")) {
            var MethodSignatures = CalculateMethodSignatures(ComponentMetadata);

            for(var method in ComponentMetadata.functions) {

                var MethodStructure = {
                    Name: method.name,
                    Signature: structKeyExists(MethodSignatures.Data, method.name) ? MethodSignatures.Data[method.name] : null,
                    Hint: structKeyExists(method, "hint") ? method.hint : "",
                    Output: method.output,
                    ReturnType: method.returnType,
                    ReturnFormat: method.returnFormat,
                    Arguments: {
                        Required: [],
                        Optional: []
                    }
                };

                for(var parameter in method.parameters) {

                    var ArgumentStructure = {
                        Name: parameter.name,
                        Type: parameter.type,
                        Default: structKeyExists(parameter, "default") ? parameter.default : false,
                        Hint: structKeyExists(parameter, "hint") ? parameter.hint : ""
                    };

                    if (parameter.required IS true)
                        MethodStructure.Arguments.Required.append(ArgumentStructure);
                    else
                        MethodStructure.Arguments.Optional.append(ArgumentStructure);
                };

                if (!structKeyExists(ComponentStructure.Methods, method.access))
                    ComponentStructure.Methods[method.access] = [];

                ComponentStructure.Methods[method.access].append(MethodStructure);
            };
        };

        if (arguments.saveToDisk IS true) {
            try {
                var SerializedComponent = serializeJSON(ComponentStructure);
            }
            catch(any error) {
                ReturnData.Errors.append("Error building component manifest - component struct couldn't be serialized before writing to disk: #ComponentMetadata.fullName#");
                return ReturnData;
            }

            fileWrite("#variables.manifestsFolder#/#ComponentStructure.Name#.json", SerializedComponent);
        }

        ReturnData.Data = ComponentStructure;

        return ReturnData;
        </cfscript>
    </cffunction>

    <cffunction name="VisualizeComponent" access="public" returntype="string" output="false" >
        <cfargument name="componentName" type="string" required="true" default="" hint="" />
        
        <cfscript>

        var ComponentVisualization = "";
        var ComponentManifest = GetComponentManifest(arguments.componentName);

        if (structIsEmpty(ComponentManifest))
            return "";

        </cfscript>
        <cfsavecontent variable="ComponentVisualization">
            <cfoutput>

            <section id="#ComponentManifest.Name#">
            <p style="font-size: 2rem">#ComponentManifest.Name# (#lsDateTimeFormat(ComponentManifest.CreatedOn, "dd/mm/yyyy - HH:nn:ss")#):</p>

                <table border="1">
                    <tr>
                        <th style="text-align:left; background-color: cornflowerblue; color: white" >Absolute Path</th>
                        <td style="background-color: lightgrey">#encodeForHTML(ComponentManifest.AbsolutePath)#</td>
                    </tr>
                    <tr>
                        <th style="text-align:left; background-color: cornflowerblue; color: white" >Dotted Path</th>
                        <td style="background-color: lightgrey">#ComponentManifest.DottedPath#</td>
                    </tr>
                    <tr>
                        <th style="text-align:left; background-color: cornflowerblue; color: white" >Display Name</th>
                        <td style="background-color: lightgrey">#len(ComponentManifest.DisplayName) GT 0 ? ComponentManifest.DisplayName : "<i>N/A</i>"#</td>
                    </tr>
                    <tr>
                        <th style="text-align:left; background-color: cornflowerblue; color: white" >Hint</th>
                        <td style="background-color: lightgrey">#len(ComponentManifest.Hint) GT 0 ? ComponentManifest.Hint : "<i>N/A</i>"#</td>
                    </tr>
                    <tr>
                        <th style="text-align:left; background-color: cornflowerblue; color: white" >Extends</th>
                        <td style="background-color: lightgrey">#len(ComponentManifest.Extends) GT 0 ? '<span style="color: blue; font-weight: bold">#ComponentManifest.Extends#</span>' : "<i>N/A</i>"#</td>
                    </tr>
                    <tr>
                        <th style="text-align:left; background-color: cornflowerblue; color: white" >Output</th>
                        <td style="background-color: lightgrey"><span style="color: #ComponentManifest.Output ? 'red' : 'green'#; font-weight: bold">#ComponentManifest.Output#</span></td>
                    </tr>
                </table>

                <h3><u>METHODS:</u></h3>

                <cfloop collection=#ComponentManifest.Methods# item="AccessType" >
                <ul>
                    <span style="background-color: lightcoral;font-size: 1.5rem">--#uCase(AccessType)#: (#arrayLen(ComponentManifest.Methods[AccessType])#)</span>
                    <br/><br/>

                    <ul style="background-color: lightblue">
                    <cfloop array=#ComponentManifest.Methods[AccessType]# index="CurrentMethod" >
                        <b style="color: darkblue; font-size: 1.2rem">#CurrentMethod.Name#()</b>
                        <ul>
                        <li><b><i style="color: white;">return type:</i> <span style="color: #CurrentMethod.ReturnType EQ 'void' ? 'red' : 'green'#">#CurrentMethod.ReturnType#</span></b></li>
                        <li><i style="color: white; font-weight: bold">hint:</i> #CurrentMethod.Hint#</li>
                        <li><b><i style="color: white;">output:</i> <span style="color: #CurrentMethod.Output ? 'red' : 'green'#">#yesNoFormat(CurrentMethod.Output)#</span></b></li>
                        <li><i style="color: white; font-weight: bold">return format:</i> #CurrentMethod.ReturnFormat#</li>
                        <li><i style="color: white; font-weight: bold">signature:</i> #CurrentMethod.Signature#</li>

                        <br>
                        <li><i><span style="font-weight: bold">ARGUMENTS</i>:</span></li>

                            <ul style="background-color: lightcyan">
                            <cfloop collection=#CurrentMethod.Arguments# item="RequirementLevel" >
                                <span style="color: white;background-color: lightskyblue">--#uCase(RequirementLevel)#: (#arrayLen(CurrentMethod.Arguments[RequirementLevel])#)</span>
                                <br/><br/>

                                <ul>
                                <cfloop array=#CurrentMethod.Arguments[RequirementLevel]# index="CurrentArgument" >
                                    <li><b style="color: darkblue; font-size: 1.2rem">#CurrentArgument.Name#</b></li>
                                    <ul>
                                        <li><b><i style="color: blue">type</i>: <span style="color: green">#CurrentArgument.Type#</span></b></li>
                                        <li><i style="color: blue; font-weight: bold">default</i>: #len(CurrentArgument.Default) IS 0 ? "<i>[an empty string]</i>" : CurrentArgument.Default#</li>
                                        <li><i style="color: blue; font-weight: bold">hint</i>: #CurrentArgument.Hint#</li>
                                        <br/>
                                    </ul>
                                </cfloop>
                                </ul>

                            </cfloop>
                            </ul>

                        </ul>
                        <br/>
                    </cfloop>
                    </ul>

                </ul>
                </cfloop>

            </section>
            </cfoutput>
        </cfsavecontent>

        <cfreturn ComponentVisualization />
    </cffunction>

    <cffunction name="BuildEntireComponentIndex" access="public" returntype="struct" output="false" hint="Goes through all the CFC's found under the mapping this instance is associated with, and builds a manifest of them" >
        <cfargument name="saveManifestsToDisk"  type="boolean" required="true"  hint="Whether to save the created manifests to the manifests-folder as supplied by the mapping during init" />
        <cfargument name="recurse"              type="boolean" required="false" default="true" hint="Whether to index the CFC's found in sub-folders" />

        <cfscript>
            arrayClear(variables.componentManifests);

            var ReturnData = {Data: variables.componentManifests, Errors: arrayNew(1, true)}; // Has to be sync'ed because we access it async
            var Paths = BuildComponentPaths(variables.componentMapping, arguments.recurse);

            if (!arrayIsEmpty(Paths.Errors)) {
                arrayAppend(ReturnData.Errors, Paths.Errors, true);
                return ReturnData;
            }

            var SaveManifestsToDisk = arguments.saveManifestsToDisk;

            arrayEach(Paths.DottedPaths, (required string componentPath)=> {

                var Manifest = BuildComponentManifest(componentPath, SaveManifestsToDisk);
                
                if (arrayIsEmpty(Manifest.Errors))
                    variables.componentManifests.append(Manifest.Data);
                else
                    arrayAppend(ReturnData.Errors, Manifest.Errors, true);
                
            }, true);

            return ReturnData;
        </cfscript>
    </cffunction>

    <cffunction name="BuildSingleComponentIndex" access="public" returntype="struct" output="false" hint="Goes through all the CFC's found under the mapping this instance is associated with, and builds a manifest of them" >
        <cfargument name="componentName" type="string"  required="true"  hint="The name of the component file, minus the extension" />
        <cfargument name="saveToDisk"    type="boolean" required="true"  hint="Whether to save the created manifest to the manifests-folder as supplied by the mapping during init" />
        <cfargument name="recurse"       type="boolean" required="false" default="true" hint="" />

        <cfscript>
            var ReturnData = {Data: null, Errors: []};

            if (trim(right(arguments.componentName, 4)) IS ".cfc") {
                ReturnData.Errors.append("Error building single component index - argument 'componentName' should be without the extension");
                return ReturnData;
            }

            var ComponentName = arguments.componentName;
            var ComponentIndex = arrayFind(variables.componentManifests, (required struct ComponentManifest)=> {
                return arguments.ComponentManifest.name EQ ComponentName
            });

            var ComponentPaths = BuildComponentPaths(variables.componentMapping, arguments.recurse, [arguments.componentName]);
            
            if (!arrayIsEmpty(ComponentPaths.Errors)) {
                arrayAppend(ReturnData.Errors, ComponentPaths.Errors, true);
                return ReturnData;
            }

            var ComponentManifest = BuildComponentManifest(ComponentPaths.DottedPaths[1], true);

            if (!arrayIsEmpty(ComponentManifest.Errors)) {
                arrayAppend(ReturnData.Errors, ComponentManifest.Errors, true);
                return ReturnData;
            }

            if (ComponentIndex GT 0)
                variables.componentManifests[ComponentIndex] = ComponentManifest.Data;
            else
                variables.componentManifests.append(ComponentManifest.Data);

            ReturnData.Data = ComponentManifest.Data;
            return ReturnData;
        </cfscript>
    </cffunction>

    <cffunction name="GetMethodSignatures" access="public" returntype="struct" output="false" hint="" >
        <cfargument name="componentName" type="string" required="true" hint="The name of the component, minus extension, which exists in the index" />

        <cfscript>
            var ReturnData = {Data: {}, Errors: []};
            var ComponentManifest = GetComponentManifest(arguments.componentName);
            
            if (structIsEmpty(ComponentManifest)) {
                ReturnData.Errors.append("Error getting method signatures - there's no component manifest for a component with name #arguments.componentName#");
                return ReturnData;
            }

            for(var AccessType in ComponentManifest.Methods)
                for(var Method in ComponentManifest.Methods[AccessType])
                    ReturnData.Data[Method.Name] = Method.Signature;

            if (structIsEmpty(ReturnData.Data))
                ReturnData.Errors.append("Error getting method signatures - none of the methods have signatures for component with name #arguments.componentName#");

            return ReturnData;
        </cfscript>
    </cffunction>

    <cffunction name="CalculateMethodSignatures" access="public" returntype="struct" output="false" hint="Calculates the signature (checksum) of every method for a given CFC. Note that this is done for the CFC on disk so the info is real-time" >
        <cfargument name="CFMetaDataStruct" type="struct" required="false" default="true" hint="The name of the component, minus extension, which exists in the index" />
        
        <cfscript>
            var ReturnData = {Data: {}, Errors: []};
            var FileHandle = createObject("java", "java.nio.file.FileSystems").getDefault().getPath(arguments.CFMetaDataStruct.path, []);
            var MethodBodies = {};

            try {
                var FileContent = createObject("java", "java.nio.file.Files").readAllLines(FileHandle);
                // FileContent is an array of strings, each index being a single line from the file
            }
            catch(any error)
            {
                ReturnData.Errors.append("Error getting method body by script style - unable to read the CFC file (#MetaData.path#): #error.message#");
                return ReturnData;
            }
    
            for (var Method in arguments.CFMetaDataStruct.functions) {
    
                //This is better because a string will constantly be redeclared when added to
                var FunctionBody = [];
                var LineIndex = 1;
    
                for(var Line in FileContent) {
                    if (LineIndex GTE Method.position.start AND LineIndex LTE Method.position.end)
                        FunctionBody.append(Line);
                    
                    LineIndex++;
                }
    
                MethodBodies[Method.name] = arrayToList(FunctionBody, "");
            }

            for(var MethodName in MethodBodies)
                ReturnData.Data[MethodName] = hash(MethodBodies[MethodName], "SHA");

            return ReturnData;
        </cfscript>
    </cffunction>

    <cffunction name="BuildComponentPaths" access="public" returntype="struct" output="false" hint="Returns the absolute paths and dotted paths of all the CFC's based on the mapping passed" >
        <cfargument name="mapping"  type="string"    required="true"  hint="The application mapping pointing to where the CFC's are" />
        <cfargument name="recurse"  type="boolean"   required="false" default="true" hint="" />
        <cfargument name="filterOn" type="array"     required="false" default="#[]#" hint="List of CFC names you want to limit the paths building to" />

        <cfscript>
            var ReturnData = {
                FilePaths: null, // Array
                DottedPaths: null, // Array
                Errors: []
            };
            var WorkingDir = expandPath(arguments.mapping);
            var FilterString = null;
            
            if (!directoryExists(WorkingDir)) {
                ReturnData.Errors.append("Error getting component paths: the directory extrapolated from the mapping you passed (#arguments.mapping#) does not exist: #WorkingDir#");
                return ReturnData;
            }

            if (arrayIsEmpty(arguments.filterOn))
                FilterString = "*.cfc";
            else
                FilterString = arrayToList(arrayMap(arguments.filterOn, (required string cfcName)=> trim(cfcName) & ".cfc"), "|");

            ReturnData.FilePaths = directoryList(
                path=WorkingDir,
                recurse=arguments.recurse,
                type="file",
                filter=FilterString,
                listInfo="path"
            );

            var MappingName = arguments.mapping;

            ReturnData.DottedPaths = arrayMap(ReturnData.FilePaths, (required string ComponentPath)=> {
                var MinusExtension = listFirst(ComponentPath, ".");
                var MinusThePath = replace(MinusExtension, WorkingDir, "");
                var MappingAtTheStart = replace(MappingName, "/", "") & MinusThePath;
                return reReplace(MappingAtTheStart, "\\|/", ".", "ALL");
            });

            return ReturnData;
        </cfscript>
    </cffunction>

    <cffunction name="init" access="public" returntype="ComponentManager" output="false" hint="Constructor" >
        <cfargument name="CFCMapping"       type="string" required="true" hint="The application mapping pointing to your CFC's" />
        <cfargument name="ManifestsMapping" type="string" required="true" hint="" />

        <!--- Set defaults for the internal vars, as the default-attrib of cfproperty only allows for string values  --->
        <cfset variables.componentManifests = arrayNew(1, true) />

        <cfscript>
            variables.componentMapping = arguments.CFCMapping;
            variables.componentsRootFolder = expandPath(arguments.CFCMapping);
            variables.manifestsFolder = expandPath(arguments.ManifestsMapping);

            if (!directoryExists(variables.componentsRootFolder))
                throw(message="Error initializing ComponentManager-instance", detail="The directory extrapolated from the CFCMapping-argument (#arguments.CFCMapping#) does not exist: #variables.componentsRootFolder#");

            if (!directoryExists(variables.manifestsFolder))
                throw(message="Error initializing ComponentManager-instance", detail="The directory extrapolated from the ManifestsMapping-argument (#arguments.ManifestsMapping#) does not exist: #variables.manifestsFolder#");

            var ManifestFiles = directoryList(
                path=variables.manifestsFolder,
                recurse=false,
                type="file",
                filter="*.json",
                listInfo="path"
            );

            if(!arrayIsEmpty(ManifestFiles)) {
                variables.componentPaths.FilePaths = [];
                variables.componentPaths.DottedPaths = [];
            }

            for(var CurrentManifest in ManifestFiles) {

                var ManifestContents = fileRead(CurrentManifest);
                try {
                    var DeserializedManifestContents = deserializeJSON(ManifestContents);
                }
                catch(any error) {
                    throw(message="Error initializing ComponentManager-instance", detail="Manifest appears to be corrupt as it cannot be deserialized: #CurrentManifest#");
                };

                variables.componentManifests.append(DeserializedManifestContents);
            };

            return this;
        </cfscript>
    </cffunction>
</cfcomponent>