component output="false" {
    // This registry authorizes identities, never stores live schedule state.
    public struct function load() output="false" {
        var config = {environment="", enabled=false, baseUrl="", schedulerTimezone="", verifiedEngineVersion="", tasks=[]};
        var configPath = "";
        if (!structKeyExists(application, "env") OR !structKeyExists(application, "stripeConfigPath")) {
            return config;
        }
        config.environment = lCase(trim(toString(application.env)));
        configPath = getDirectoryFromPath(application.stripeConfigPath) & "scheduler-config.json";
        if (fileExists(configPath)) {
            config = deserializeJSON(fileRead(configPath, "utf-8"));
        }
        return config;
    }
}
