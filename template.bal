import ballerina/websub;
//import ballerina/log;
import ballerina/io;
import ballerinax/github.webhook;
//import ballerinax/googleapis_sheets as sheets;
import ballerinax/slack;

// GitHub configuration parameters
configurable string github_accessToken = ?;
configurable string github_callbackUrl = ?;
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
    callback: github_callbackUrl,
    secret: github_secret,
    httpConfig: {
        auth: {
            token: github_accessToken
        }
    }
}
service websub:SubscriberService /subscriber on githubListener {
    remote function onEventNotification(websub:ContentDistributionMessage event) {
        var payload = githubListener.getEventType(event);

        io:StringReader sr = new (event.content.toJsonString());
        json|error releaseInfo = sr.readJson();

        if (releaseInfo is json) {
            if (releaseInfo.action == "released") {
                io:println(releaseInfo);
                if (releaseInfo.release is json) {
                    sendMessageWithContactCreation(releaseInfo);
                }
            }
        } else {
            io:println("Error Occured : ");
        }
    }
}

function sendMessageWithContactCreation(json release) {
    string message = "There is new release in GitHub \n";
    map<json> contactsMap = <map<json>> release;
    foreach var [key, value] in contactsMap.entries() {
        if(value != ()) {
            message = message + key + " : " + value.toString() + "\n";
        }
    }

    slack:Message newMessage = {
        channelName: slack_channel_name,
        text: "TEXT MESSAGE"
    };
    string|error slackResponse = slackClient->postMessage(newMessage);

    if slackResponse is string {
        io:print("Messege posted in Slack Successfully");
    } else {
        io:println("Error Occured : " + slackResponse.message());
    }
}
