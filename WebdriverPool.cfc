<cfcomponent displayname="WebdriverPool" output="false" accessors="false" persistent="true">

    <cfproperty name="pool"                 type="array"    getter="true"   setter="false" hint="A synchronized array of org.openqa.selenium.remote.RemoteWebDriver-instances" />
    <cfproperty name="availabilityQueue"    type="any"      getter="false"  setter="false" hint="An instance of java.util.concurrent.ArrayBlockingQueue used for available webdriver instances" />

	<cffunction name="init" access="public" returntype="WebdriverPool" hint="Constructor" >
        <cfargument name="size" type="numeric" required="true" hint="The size of the pool. This is fixed at instansiation and cannot be changed later." >

        <cfset variables.pool = arrayNew(dimension=1, synchronized=true) />
        <cfset variables.availabilityQueue = createObject("java", "java.util.concurrent.ArrayBlockingQueue").init(arguments.size, true) />

        <cfscript>
        for(var index = 1; index < (arguments.size + 1); index++) {

            var chromeoptions = createObject("java", "org.openqa.selenium.chrome.ChromeOptions").init();
            chromeoptions.addArguments([
                "--start-maximized",
                "--no-proxy-server",
                "--disable-gpu",
                "--headless",
                "--window-size=1920,1080",
                "--settings=imagesEnabled=false"
            ]);

            var driver = createObject("java", "org.openqa.selenium.remote.RemoteWebDriver").init(
                createObject("java", "java.net.URL").init("http://localhost:9515"),
                chromeoptions
            );

            variables.pool.append(driver);
            variables.availabilityQueue.add(
                new PoolObject(index,driver,(required numeric id)=> variables.release(arguments.id))
            );
        }

        return this;
        </cfscript>
	</cffunction>

    <cffunction name="request" access="public" returntype="PoolObject" hint="Request an object from the pool. If the queue is empty (and no timeout is specified), this call will block until an object is available. Objects are returned to the callers in the order they called (FIFO)" >
        <cfargument name="timeout" type="numeric" required="false" default="0" hint="Waits this amount of seconds for an object to become available. Returns null if the timeout is reached" >

        <cfif arguments.timeout LTE 0 >
            <cfreturn variables.availabilityQueue.take() />
        <cfelse>
            <cfreturn variables.availabilityQueue.poll(
                arguments.timeout,
                createObject("java.util.concurrent.TimeUnit").SECONDS)
            />
        </cfif>
    </cffunction>

    <cffunction name="availableAmount" access="public" returntype="numeric" hint="Returns the amount of objects currently available" >
        <cfreturn variables.availabilityQueue.size() />
    </cffunction>

	<cffunction name="release" access="private" returntype="void" hint="Releases the object back into the pool. Called indirectly via the PoolObjects that are spawned by request(), who are passed a pointer to this method" >
        <cfargument name="poolObjectID" type="numeric" required="true" >

        <cfset variables.availabilityQueue.add(
            new PoolObject(
                arguments.poolObjectID,
                variables.pool[arguments.poolObjectID],
                (required numeric id)=> variables.release(arguments.id)
            )
        ) />
	</cffunction>

    <cffunction name="dispose" access="public" returntype="void" hint="Disposes of the objects in the pool, releasing all resources they are holding" >
        <cfset arrayEach(variables.pool, (webdriver)=> {
            try {
                arguments.webdriver.quit();
            }
            catch(any error) {
                <!--- Nothing... --->
            }
        }, true) />
    </cffunction>
</cfcomponent>