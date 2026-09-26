___TERMS_OF_SERVICE___
By creating or modifying this file, you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service located at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.
___END_TERMS_OF_SERVICE___

___TEMPLATE_PARAMETERS___
[
  {
    "type": "TEXT",
    "name": "buyerAcceptsMarketing",
    "displayName": "buyer_accepts_marketing value",
    "simpleValueType": true,
    "help": "Pass the buyer_accepts_marketing field from your webhook event data, e.g. {{Event Data - buyer_accepts_marketing}}"
  }
]
___END_TEMPLATE_PARAMETERS___

___SANDBOXED_JS_FOR_WEB_TEMPLATE___

var value = data.buyerAcceptsMarketing;
var consent = (value === true || value === 'true');

return {
  ad_storage:              consent,
  ad_user_data:            consent,
  ad_personalization:      consent,
  analytics_storage:       consent,
  functionality_storage:   true,
  personalization_storage: consent,
  security_storage:        true
};

___END_SANDBOXED_JS_FOR_WEB_TEMPLATE___

___WEB_PERMISSIONS___
[]
___END_WEB_PERMISSIONS___