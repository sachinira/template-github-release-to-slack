//import ballerina/io;
import ballerina/websub;
import ballerinax/github.webhook;
import ballerinax/slack;

configurable string github_access_token = ?;
configurable string github_callback_url = ?;
configurable string github_topic = ?;
configurable string github_secret = ?;
configurable string slack_token = ?;
configurable string slack_channel_name = ?;

listener webhook:Listener githubListener = new(8080);
slack:Configuration slackConfig = {bearerTokenConfig: {token: slack_token}};
slack:Client slackClient = check new (slackConfig);

@websub:SubscriberServiceConfig {
    target: [webhook:HUB, github_topic],
    callback: github_callback_url,
    httpConfig: {
        auth: {
            token: github_access_token
        }
    }
}
service /subscriber on githubListener {
    remote function onReleased(webhook:ReleaseEvent event) returns error? {
        webhook:Release releaseInfo = event.release; 
        string message = "There is a new release in GitHub ! \n";
        [string,string][] releaseTuples = [[VERSION_NUMBER, RELEASE_TAG_NAME], [TARGET_BRANCH, TARGET_COMMITTISH]];

        message += "<" + releaseInfo.get(RELEASE_URL).toString() + ">\n";  
        foreach var releaseTuple in releaseTuples {
            var [description,keyFromMap] = releaseTuple;
            if (releaseInfo.hasKey(keyFromMap)) {
                message += description + SEMICOLON + releaseInfo.get(keyFromMap).toString() + "\n";  
            }   
        }
        slack:Message newMessage = {
            channelName: slack_channel_name,
            text: message
        };
        _ = check slackClient->postMessage(newMessage);
    }
}
