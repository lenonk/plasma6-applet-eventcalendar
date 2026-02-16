#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QCoreApplication>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QOAuth2AuthorizationCodeFlow>
#include <QOAuthHttpServerReplyHandler>
#include <QProcess>
#include <QTimer>
#include <QUrl>
#include <QVariantMap>

#include <cstdio>

static void printJsonLine(const QJsonObject &obj)
{
    const auto json = QJsonDocument(obj).toJson(QJsonDocument::Compact);
    std::fwrite(json.constData(), 1, static_cast<size_t>(json.size()), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}

static void printErrLine(const QString &msg)
{
    const auto utf8 = msg.toUtf8();
    std::fwrite(utf8.constData(), 1, static_cast<size_t>(utf8.size()), stderr);
    std::fputc('\n', stderr);
    std::fflush(stderr);
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("eventcalendar-google-oauth"));

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("Event Calendar Google OAuth helper"));
    parser.addHelpOption();

    const QCommandLineOption clientIdOpt(
        {QStringLiteral("i"), QStringLiteral("client-id")},
        QStringLiteral("OAuth client ID"),
        QStringLiteral("client_id"));
    const QCommandLineOption clientSecretOpt(
        {QStringLiteral("s"), QStringLiteral("client-secret")},
        QStringLiteral("OAuth client secret (optional for PKCE public clients)"),
        QStringLiteral("client_secret"),
        QString());
    const QCommandLineOption portOpt(
        {QStringLiteral("p"), QStringLiteral("port")},
        QStringLiteral("Loopback port (default: 8400)"),
        QStringLiteral("port"),
        QStringLiteral("8400"));
    const QCommandLineOption scopesOpt(
        {QStringLiteral("scope"), QStringLiteral("scopes")},
        QStringLiteral("Space-separated OAuth scopes"),
        QStringLiteral("scopes"),
        QStringLiteral("https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/tasks"));
    const QCommandLineOption timeoutOpt(
        {QStringLiteral("t"), QStringLiteral("timeout")},
        QStringLiteral("Timeout in seconds (default: 300)"),
        QStringLiteral("seconds"),
        QStringLiteral("300"));

    parser.addOption(clientIdOpt);
    parser.addOption(clientSecretOpt);
    parser.addOption(portOpt);
    parser.addOption(scopesOpt);
    parser.addOption(timeoutOpt);
    parser.process(app);

    const QString clientId = parser.value(clientIdOpt).trimmed();
    const QString clientSecret = parser.value(clientSecretOpt);

    bool portOk = false;
    int port = parser.value(portOpt).toInt(&portOk);
    if (!portOk || port <= 0 || port > 65535) {
        port = 8400;
    }

    bool timeoutOk = false;
    int timeoutSec = parser.value(timeoutOpt).toInt(&timeoutOk);
    if (!timeoutOk || timeoutSec <= 0) {
        timeoutSec = 300;
    }

    const QString scopes = parser.value(scopesOpt).trimmed();

    if (clientId.isEmpty()) {
        printErrLine(QStringLiteral("Missing required argument: --client-id"));
        return 2;
    }

    auto *replyHandler = new QOAuthHttpServerReplyHandler(QHostAddress(QStringLiteral("127.0.0.1")),
                                                          static_cast<quint16>(port), &app);
    replyHandler->setCallbackHost(QStringLiteral("127.0.0.1"));
    replyHandler->setCallbackPath(QStringLiteral("/"));
    replyHandler->setCallbackText(QStringLiteral(
        "<!doctype html>"
        "<html><head><meta charset=\"utf-8\">"
        "<title>Event Calendar</title>"
        "<style>"
        "body{font-family:sans-serif;margin:2rem;max-width:48rem;}"
        "code{background:#f2f2f2;padding:.1rem .25rem;border-radius:.2rem;}"
        "</style></head>"
        "<body>"
        "<h2>Login complete</h2>"
        "<p>You can close this window and return to the Event Calendar widget configuration.</p>"
        "</body></html>"));

    if (!replyHandler->isListening()) {
        if (!replyHandler->listen(QHostAddress(QStringLiteral("127.0.0.1")),
                                  static_cast<quint16>(port))) {
            printErrLine(QStringLiteral("Failed to listen on http://127.0.0.1:%1/ (port in use?)")
                             .arg(port));
            return 3;
        }
    }

    QOAuth2AuthorizationCodeFlow oauth;
    oauth.setReplyHandler(replyHandler);
    oauth.setAuthorizationUrl(QUrl(QStringLiteral("https://accounts.google.com/o/oauth2/v2/auth")));
    oauth.setAccessTokenUrl(QUrl(QStringLiteral("https://oauth2.googleapis.com/token")));
    oauth.setClientIdentifier(clientId);
    if (!clientSecret.isEmpty()) {
        oauth.setClientIdentifierSharedKey(clientSecret);
    }
    oauth.setScope(scopes);
    oauth.setPkceMethod(QOAuth2AuthorizationCodeFlow::PkceMethod::S256);

    oauth.setModifyParametersFunction([](QAbstractOAuth::Stage stage,
                                         QMultiMap<QString, QVariant> *parameters) {
        // Request a refresh token.
        if (stage == QAbstractOAuth::Stage::RequestingAuthorization) {
            parameters->insert(QStringLiteral("access_type"), QStringLiteral("offline"));
            parameters->insert(QStringLiteral("prompt"), QStringLiteral("consent"));
            parameters->insert(QStringLiteral("include_granted_scopes"), QStringLiteral("true"));
        }
    });

    QObject::connect(&oauth, &QAbstractOAuth::authorizeWithBrowser, &app,
                     [&](const QUrl &url) {
                         const bool started = QProcess::startDetached(QStringLiteral("xdg-open"),
                                                                      {url.toString()});
                         if (!started) {
                             printErrLine(QStringLiteral("Failed to open web browser via xdg-open."));
                             app.exit(5);
                         }
                     });

    QObject::connect(&oauth, &QAbstractOAuth::requestFailed, &app,
                     [&](QAbstractOAuth::Error error) {
                         printErrLine(QStringLiteral("OAuth failed (requestFailed=%1).")
                                          .arg(static_cast<int>(error)));
                         app.exit(1);
                     });

    QObject::connect(&oauth, &QAbstractOAuth::granted, &app, [&]() {
        const QVariantMap extra = oauth.extraTokens();

        QJsonObject obj;
        obj.insert(QStringLiteral("access_token"), oauth.token());

        QString tokenType = extra.value(QStringLiteral("token_type")).toString();
        if (tokenType.isEmpty()) {
            tokenType = QStringLiteral("Bearer");
        }
        obj.insert(QStringLiteral("token_type"), tokenType);

        int expiresIn = extra.value(QStringLiteral("expires_in")).toInt();
        if (expiresIn <= 0) {
            const QDateTime exp = oauth.expirationAt();
            if (exp.isValid()) {
                expiresIn = static_cast<int>(QDateTime::currentDateTimeUtc().secsTo(exp));
                if (expiresIn < 0) {
                    expiresIn = 0;
                }
            }
        }
        obj.insert(QStringLiteral("expires_in"), expiresIn);

        const QString refresh = oauth.refreshToken();
        if (!refresh.isEmpty()) {
            obj.insert(QStringLiteral("refresh_token"), refresh);
        }

        printJsonLine(obj);
        app.exit(0);
    });

    QTimer timeout;
    timeout.setSingleShot(true);
    QObject::connect(&timeout, &QTimer::timeout, &app, [&]() {
        printErrLine(QStringLiteral("OAuth timed out after %1 seconds.").arg(timeoutSec));
        app.exit(4);
    });
    timeout.start(timeoutSec * 1000);

    oauth.grant();
    return app.exec();
}
