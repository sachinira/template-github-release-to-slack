import ballerina/http;
import ballerina/websub;
import ballerinax/github.webhook;
import ballerinax/slack;

configurable string & readonly gitHubCallbackUrl = ?;
configurable string & readonly gitHubTopic = ?;
configurable int & readonly port = ?;
configurable http:BearerTokenConfig & readonly gitHubTokenConfig = ?;
configurable string & readonly slackChannelName = ?;
configurable http:BearerTokenConfig & readonly slackTokenConfig = ?;

listener webhook:Listener githubListener = new(port);

slack:Configuration slackConfig = {
    bearerTokenConfig: slackTokenConfig
};
slack:Client slackClient = check new (slackConfig);

@websub:SubscriberServiceConfig {
    target: [webhook:HUB, gitHubTopic],
    callback: gitHubCallbackUrl,
    httpConfig: {
        auth: gitHubTokenConfig
    }
}
service / on githubListener {
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
            channelName: slackChannelName,
            text: message
        };
        _ = check slackClient->postMessage(newMessage);
    }
}
