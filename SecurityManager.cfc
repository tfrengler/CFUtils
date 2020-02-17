<cfcomponent modifier="final" hint="Utility component, used for common security related tasks. Note that a secretKey is generated upon instantiation which is used for the authKey as well as encryption/decryption during the instance's lifetime" >

	<!--- PROPERTIES --->
	<cfset variables.characterInterface = createObject("java", "java.lang.Character") />
	<cfset variables.XORCharDelimiter = "|" />
	<cfset variables.validChecksumAlgorithms = ["MD2","MD5","SHA-1","SHA-256","SHA-384","SHA-512"] />
	<cfset variables.secretKey = generateSecretKey("AES", 128) />

	<!--- PUBLIC --->
	<cffunction name="getXOREncodedString" returntype="string" access="public" output="true" >
		<cfargument name="mask" type="string" required="true" hint="A string exactly as long as the stringToEncode" />
		<cfargument name="stringToEncode" type="string" required="true" hint="The value you wish to encode" />

		<cfif len(arguments.stringToEncode) IS 0 >
			<cfreturn "" />
		</cfif>

		<cfif len(arguments.mask) IS NOT len(arguments.stringToEncode) >
			<cfthrow message="Error generating interleaved mask" detail="Mask and string are not the same length" />
		</cfif>

		<cfset var currentIndex = 0 />
		<cfset var charCode = 0 />
		<cfset var maskKeyToUse = 0 />
		<cfset var maskKeyCode = 0 />
		<cfset var charCodeMasked = 0 />
		<cfset var hexedChar = "" />
		<cfset var returnData = [] />

		<cfloop from="0" to=#len(arguments.stringToEncode)-1# index="currentIndex" >
	
			<cfset charCode = variables.characterInterface.codePointAt(stringToEncode, currentIndex) />
			<cfset maskKeyToUse = currentIndex mod len(arguments.mask) />
			<cfset maskKeyCode = variables.characterInterface.codePointAt(arguments.mask, maskKeyToUse) />
			<cfset charCodeMasked = bitXor(charCode, maskKeyCode) />
			<cfset hexedChar = formatBaseN(charCodeMasked, 16) />
			
			<cfset arrayAppend(returnData, hexedChar) />
			<cfset arrayAppend(returnData, variables.XORCharDelimiter) />

		</cfloop>

		<cfset returnData = arrayToList(returnData, "") />
		<cfreturn left(returnData, len(returnData)-1) />
	</cffunction>

	<cffunction name="getXORDecodedString" returntype="string" access="public" >
		<cfargument name="mask" type="string" required="true" hint="The mask used to encode the string" />
		<cfargument name="stringToDecode" type="string" required="true" hint="The value you wish to decode" />

		<cfif len(arguments.stringToDecode) IS 0 >
			<cfreturn "" />
		</cfif>

		<cfset var maskKeyToUse = 0 />
		<cfset var maskKeyCode = 0 />
		<cfset var maskedCharCode = 0 />
		<cfset var unmaskedCharCode = 0 />
		<cfset var char = "" />
		<cfset var index = 0 />
		<cfset var decoded = [] />

		<cfloop from="0" to=#listLen(arguments.stringToDecode, variables.XORCharDelimiter)-1# index="index" >

			<cfset maskKeyToUse = index mod len(arguments.mask) />
			<cfset maskKeyCode = variables.characterInterface.codePointAt(arguments.mask, maskKeyToUse) />
			<cfset maskedCharCode = inputBaseN(listGetAt(arguments.stringToDecode, index+1, variables.XORCharDelimiter), 16) />
			<cfset unmaskedCharCode = bitXor(maskedCharCode, maskKeyCode) />
		
			<cfset char = variables.characterInterface.toChars(unmaskedCharCode) />
			
			<cfset arrayAppend(decoded, char) />
		</cfloop>

		<cfreturn arrayToList(decoded, "") />
	</cffunction>

	<cffunction name="getChecksum" returntype="string" access="public" >
		<cfargument name="filePath" type="string" required="false" default="" hint="The absolute path and name of a file you want to create a checksum for. Takes precedence over 'stringContent'" />
		<cfargument name="stringContent" type="string" required="false" default="" hint="The string content you want to create a checksum from" />
		<cfargument name="algorithm" type="string" required="false" default=#variables.validChecksumAlgorithms[5]# hint="Algorithm to use. By default SHA-384 is used" />
	
		<cfif arrayFind(variables.validChecksumAlgorithms, arguments.algorithm) IS 0 >
			<cfthrow message="Unable to generate checksum" detail="The algorithm you passed is invalid (#arguments.algorithm#). Valid algorithms are: #arrayToList(variables.validChecksumAlgorithms)#" />
		</cfif>

		<cfset var checksumCreator = createObject("java", "java.security.MessageDigest").getInstance(arguments.algorithm) />
		
		<cfif len(arguments.filePath) GT 0 AND fileExists(arguments.filePath) >
			<cfset arguments.stringContent = fileRead(arguments.filePath, "utf-8") />
		<cfelseif len(arguments.stringContent) IS 0 >
			<cfreturn "" />
		</cfif>

		<cfreturn toBase64(checksumCreator.digest(arguments.stringContent.getBytes()), "utf-8") />
	</cffunction>

	<cffunction name="getCSPPolicy" returntype="string" access="public" hint="Generates a CSP policy for use with 'Content-Security-Policy'-http headers" >
		<cfargument name="includeNonce" type="string" required="false" default="" />

		<cfset var CSPPolicy = "" />

		<cfoutput>
		<cfsilent>
			<cfsavecontent variable="CSPPolicy">
				default-src 'self';
				frame-src data: 'self';
				<!---Not Supported yet: require-sri-for script style; --->
				font-src 'self';
				img-src 'self';
				media-src 'self';
				object-src 'none';
				script-src 'self' <cfif len(arguments.includeNonce) GT 0 >'nonce-#arguments.nonce#'</cfif>;
				style-src 'self' <cfif len(arguments.includeNonce) GT 0 >'nonce-#arguments.nonce#'</cfif>;
				form-action 'self';
				<!--- report-uri CSPViolation.cfm; --->
			</cfsavecontent>
		</cfsilent>
		</cfoutput>

		<cfreturn CSPPolicy />
	</cffunction>

	<cffunction name="getNonce" returntype="string" access="public" hint="Returns a cryptographic nonce for use with inline JS" > 
		<cfreturn toBase64(generateSecretKey("AES", 128)) />
	</cffunction>

	<cffunction name="encryptValue" returntype="string" access="public" hint="Encrypts the given string value, returned as a base64 string" >
		<cfargument name="value" type="string" required="true" default="The string value to encrypt" />

		<cfif len(arguments.value) IS 0 >
			<cfreturn "" />
		</cfif>

		<cfreturn encrypt(arguments.value, variables.secretKey, "AES", "base64") />
	</cffunction>

	<cffunction name="decryptValue" returntype="string" access="public" hint="Decrypts the given string value" >
		<cfargument name="value" type="string" required="true" default="The string value to decrypt, base64 encoded" />

		<cfif len(arguments.value) IS 0 >
			<cfreturn "" />
		</cfif>

		<cfreturn decrypt(arguments.value, variables.secretKey, "AES", "base64") />
	</cffunction>

	<cffunction name="generateAuthKey" returntype="string" access="public" hint="Returns an authKey, typically used for AJAX calls, based on the caller's sessionID" >
		<cfargument name="sessionID" type="string" required="true" default="" />
		<cfargument name="algorithm" type="string" required="false" default=#variables.validChecksumAlgorithms[6]# hint="Algorithm to use. By default SHA-512 is used" />

		<cfif len(arguments.sessionID) IS 0 >
			<cfthrow message="Unable to generate auth key" detail="Argument 'sessionID' is empty" />
		</cfif>
	
		<cfif arrayFind(variables.validChecksumAlgorithms, arguments.algorithm) IS 0 >
			<cfthrow message="Unable to generate auth key" detail="The algorithm you passed is invalid (#arguments.algorithm#). Valid algorithms are: #arrayToList(variables.validChecksumAlgorithms)#" />
		</cfif>

		<cfreturn hash(session.sessionid & variables.secretKey, arguments.algorithm) />
	</cffunction>

</cfcomponent>