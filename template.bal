import ballerina/io;
import ballerina/log;
import ballerina/websub;
import ballerinax/github.webhook;
import ballerinax/slack;

// GitHub configuration parameters
configurable string github_access_token = ?;
configurable string github_callback_url = ?;
configurable string github_topic = ?;
configurable string github_secret = ?;

// Slack configuration parameters
configurable string slack_token = ?;
configurable string slack_channel_name = ?;

listener webhook:Listener githubListener = new (8080);

slack:Configuration slackConfig = {bearerTokenConfig: {token: slack_token}};
slack:Client slackClient = check new (slackConfig);

@websub:SubscriberServiceConfig {
    target: [webhook:HUB, github_topic],
    callback: github_callback_url,
    secret: github_secret,
    httpConfig: {
        auth: {
            token: github_access_token
        }
    }
}
service websub:SubscriberService /subscriber on githubListener {
    remote function onEventNotification(websub:ContentDistributionMessage event) {
        var payload = githubListener.getEventType(event);
        io:StringReader sr = new (event.content.toJsonString());
        json|error allInfo = sr.readJson();

        if (allInfo is json) {
            if (allInfo.action == RELEASED) {
                io:println(allInfo);
                json|error releaseInfo = allInfo.release; 
                if (releaseInfo is json) {
                    sendMessageForNewRelease(releaseInfo);
                } else {
                    log:printError(releaseInfo.message());        
                }
            }
        } else {
            log:printError(allInfo.message());        
        }
    }
}

function sendMessageForNewRelease(json release) {
    string message = "There is a new release in GitHub ! \n";
    map<json> releaseMap = <map<json>> release;
    [string,string][] releaseTuples = [[VERSION_NUMBER, RELEASE_TAG_NAME], [TARGET_BRANCH, TARGET_COMMITTISH]];

    message += "<" + releaseMap.get(RELEASE_URL).toString() + ">\n";  
    foreach var releaseTuple in releaseTuples {
        var [value,'key] = releaseTuple;
        if (releaseMap.hasKey('key)) {
            message += value + SEMICOLON + releaseMap.get('key).toString() + "\n";  
        }   
    }
    slack:Message newMessage = {
        channelName: slack_channel_name,
        text: message
    };
    string|error slackResponse = slackClient->postMessage(newMessage);

    if slackResponse is string {
        log:print("Messege posted in Slack Successfully");
    } else {
        log:printError("Error Occured : " + slackResponse.message());
    }
}
