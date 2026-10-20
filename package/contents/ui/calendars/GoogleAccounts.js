.pragma library

// Google account slots. Account 1 uses the unprefixed config keys.
var extraPrefixes = ["account2", "account3", "account4", "account5"]

// The config keys each account has its own copy of.
var accountKeys = [
	"sessionClientId", "sessionClientSecret",
	"accessToken", "accessTokenType", "accessTokenExpiresAt", "refreshToken",
	"calendarList", "calendarIdList", "tasklistList", "tasklistIdList",
]

// cfgKey("account2", "accessToken") === "account2AccessToken"
function cfgKey(prefix, key) {
	if (!prefix || accountKeys.indexOf(key) < 0) return key
	return prefix + key.charAt(0).toUpperCase() + key.slice(1)
}

// Calendar/tasklist ids of accounts 2-5 are "account2|<Google id>" outside their
// managers, so the same calendar in two accounts stays apart. Google ids never contain "|".
var idSeparator = "|"

function modelId(prefix, id) {
	return prefix ? prefix + idSeparator + id : id
}

function apiId(prefix, id) {
	var head = prefix + idSeparator
	return (prefix && ("" + id).indexOf(head) === 0) ? ("" + id).slice(head.length) : id
}
