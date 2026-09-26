___INFO___

{
  "displayName": "ID Lookup",
  "description": "Returns correct account/tracking ID based on multiple conditions.",
  "securityGroups": [],
  "id": "cvt_temp_public_id",
  "type": "MACRO",
  "version": 1,
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "displayName": "First matching rule will define the returning ID value",
    "name": "Top Info",
    "type": "LABEL"
  },
  {
    "displayName": "Testing | Debug mode | Non-production IDs",
    "name": "testingGroup",
    "groupStyle": "ZIPPY_OPEN_ON_PARAM",
    "type": "GROUP",
    "subParams": [
      {
        "simpleValueType": true,
        "name": "inDebugMode",
        "checkboxText": "Different ID for Debug Mode",
        "type": "CHECKBOX",
        "subParams": [
          {
            "enablingConditions": [
              {
                "paramName": "inDebugMode",
                "type": "EQUALS",
                "paramValue": true
              }
            ],
            "displayName": "",
            "name": "debug mode",
            "groupStyle": "NO_ZIPPY",
            "type": "GROUP",
            "subParams": [
              {
                "help": "Please select the {{Debug Mode}} variable",
                "macrosInSelect": true,
                "selectItems": [],
                "valueValidators": [
                  {
                    "type": "NON_EMPTY"
                  }
                ],
                "displayName": "Debug Mode standard Variable",
                "simpleValueType": true,
                "name": "debugModeVar",
                "type": "SELECT"
              },
              {
                "valueValidators": [
                  {
                    "type": "NON_EMPTY"
                  }
                ],
                "displayName": "ID in Debug mode",
                "simpleValueType": true,
                "name": "debugModeID",
                "type": "TEXT"
              }
            ]
          }
        ]
      },
      {
        "simpleValueType": true,
        "name": "nonProductionCheckbox",
        "checkboxText": "Non-production rules",
        "type": "CHECKBOX",
        "subParams": [
          {
            "enablingConditions": [
              {
                "paramName": "nonProductionCheckbox",
                "type": "EQUALS",
                "paramValue": true
              }
            ],
            "displayName": "Define rules to determine non production tracking",
            "name": "nonProductionGroup",
            "groupStyle": "ZIPPY_OPEN",
            "type": "GROUP",
            "subParams": [
              {
                "displayName": "Conditions",
                "name": "nonProductionLookupTable",
                "simpleTableColumns": [
                  {
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ],
                    "defaultValue": "",
                    "displayName": "Variable",
                    "name": "variable",
                    "type": "TEXT"
                  },
                  {
                    "selectItems": [
                      {
                        "displayValue": "equals",
                        "value": "equals"
                      },
                      {
                        "displayValue": "contains",
                        "value": "contains"
                      },
                      {
                        "displayValue": "starts with",
                        "value": "starts with"
                      },
                      {
                        "displayValue": "ends with",
                        "value": "ends with"
                      },
                      {
                        "displayValue": "does not equal",
                        "value": "does not equal"
                      },
                      {
                        "displayValue": "does not contain",
                        "value": "does not contain"
                      },
                      {
                        "displayValue": "does not start with",
                        "value": "does not start with"
                      },
                      {
                        "displayValue": "does not end with",
                        "value": "does not end with"
                      },
                      {
                        "displayValue": "less than",
                        "value": "less than"
                      },
                      {
                        "displayValue": "less than or equal to",
                        "value": "less than or equal to"
                      },
                      {
                        "displayValue": "greater than",
                        "value": "greater than"
                      },
                      {
                        "displayValue": "greater than or equal to",
                        "value": "greater than or equal to"
                      }
                    ],
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ],
                    "defaultValue": "contains",
                    "displayName": "Rule",
                    "name": "matchType",
                    "type": "SELECT"
                  },
                  {
                    "defaultValue": "",
                    "displayName": "Value",
                    "name": "value",
                    "type": "TEXT"
                  },
                  {
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ],
                    "defaultValue": "",
                    "displayName": "ID",
                    "name": "id",
                    "type": "TEXT"
                  }
                ],
                "type": "SIMPLE_TABLE"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    "displayName": "Production IDs",
    "name": "productionGroup",
    "groupStyle": "ZIPPY_OPEN_ON_PARAM",
    "type": "GROUP",
    "subParams": [
      {
        "simpleValueType": true,
        "name": "productionAdvancedCheckbox",
        "checkboxText": "Advanced Production rules",
        "type": "CHECKBOX",
        "subParams": [
          {
            "enablingConditions": [
              {
                "paramName": "productionAdvancedCheckbox",
                "type": "EQUALS",
                "paramValue": true
              }
            ],
            "displayName": "Define rules to determine production tracking",
            "name": "productionAdvanced Group",
            "groupStyle": "NO_ZIPPY",
            "type": "GROUP",
            "subParams": [
              {
                "displayName": "Conditions",
                "name": "productionAdvancedLookupTable",
                "simpleTableColumns": [
                  {
                    "defaultValue": "",
                    "displayName": "Variable",
                    "name": "variable",
                    "type": "TEXT",
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ]
                  },
                  {
                    "selectItems": [
                      {
                        "displayValue": "equals",
                        "value": "equals"
                      },
                      {
                        "displayValue": "contains",
                        "value": "contains"
                      },
                      {
                        "displayValue": "starts with",
                        "value": "starts with"
                      },
                      {
                        "displayValue": "ends with",
                        "value": "ends with"
                      },
                      {
                        "displayValue": "does not equal",
                        "value": "does not equal"
                      },
                      {
                        "displayValue": "does not contain",
                        "value": "does not contain"
                      },
                      {
                        "displayValue": "does not start with",
                        "value": "does not start with"
                      },
                      {
                        "displayValue": "does not end with",
                        "value": "does not end with"
                      },
                      {
                        "displayValue": "less than",
                        "value": "less than"
                      },
                      {
                        "displayValue": "less than or equal to",
                        "value": "less than or equal to"
                      },
                      {
                        "displayValue": "greater than",
                        "value": "greater than"
                      },
                      {
                        "displayValue": "greater than or equal to",
                        "value": "greater than or equal to"
                      }
                    ],
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ],
                    "defaultValue": "contains",
                    "displayName": "Rule",
                    "name": "matchType",
                    "type": "SELECT"
                  },
                  {
                    "defaultValue": "",
                    "displayName": "Value",
                    "name": "value",
                    "type": "TEXT"
                  },
                  {
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ],
                    "defaultValue": "",
                    "displayName": "ID",
                    "name": "id",
                    "type": "TEXT"
                  }
                ],
                "type": "SIMPLE_TABLE"
              }
            ]
          }
        ]
      },
      {
        "simpleValueType": true,
        "name": "productionCustomLookupCheckbox",
        "checkboxText": "Lookup by variable",
        "type": "CHECKBOX",
        "subParams": [
          {
            "enablingConditions": [
              {
                "paramName": "productionCustomLookupCheckbox",
                "type": "EQUALS",
                "paramValue": true
              }
            ],
            "displayName": "",
            "name": "productionCustomLookup Group",
            "groupStyle": "NO_ZIPPY",
            "type": "GROUP",
            "subParams": [
              {
                "macrosInSelect": true,
                "selectItems": [],
                "valueValidators": [
                  {
                    "type": "NON_EMPTY"
                  }
                ],
                "displayName": "",
                "defaultValue": "",
                "simpleValueType": true,
                "name": "productionCustomLookupVariable",
                "type": "SELECT"
              },
              {
                "displayName": "Conditions",
                "name": "productionCustomLookupTable",
                "simpleTableColumns": [
                  {
                    "selectItems": [
                      {
                        "displayValue": "equals",
                        "value": "equals"
                      },
                      {
                        "displayValue": "contains",
                        "value": "contains"
                      },
                      {
                        "displayValue": "starts with",
                        "value": "starts with"
                      },
                      {
                        "displayValue": "ends with",
                        "value": "ends with"
                      },
                      {
                        "displayValue": "does not equal",
                        "value": "does not equal"
                      },
                      {
                        "displayValue": "does not contain",
                        "value": "does not contain"
                      },
                      {
                        "displayValue": "does not start with",
                        "value": "does not start with"
                      },
                      {
                        "displayValue": "does not end with",
                        "value": "does not end with"
                      },
                      {
                        "displayValue": "less than",
                        "value": "less than"
                      },
                      {
                        "displayValue": "less than or equal to",
                        "value": "less than or equal to"
                      },
                      {
                        "displayValue": "greater than",
                        "value": "greater than"
                      },
                      {
                        "displayValue": "greater than or equal to",
                        "value": "greater than or equal to"
                      }
                    ],
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ],
                    "defaultValue": "contains",
                    "displayName": "Rule",
                    "name": "matchType",
                    "type": "SELECT"
                  },
                  {
                    "valueValidators": [],
                    "defaultValue": "",
                    "displayName": "Value",
                    "name": "value",
                    "type": "TEXT"
                  },
                  {
                    "defaultValue": "",
                    "displayName": "ID",
                    "name": "id",
                    "type": "TEXT",
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ]
                  }
                ],
                "type": "SIMPLE_TABLE"
              }
            ]
          }
        ]
      },
      {
        "simpleValueType": true,
        "name": "productionHostnameLookupCheckbox",
        "checkboxText": "Simple lookup by hostname",
        "type": "CHECKBOX",
        "subParams": [
          {
            "enablingConditions": [
              {
                "paramName": "productionHostnameLookupCheckbox",
                "type": "EQUALS",
                "paramValue": true
              }
            ],
            "displayName": "",
            "name": "productionHostname Group",
            "groupStyle": "NO_ZIPPY",
            "type": "GROUP",
            "subParams": [
              {
                "help": "If enabled, the leading \u0027www.\u0027 of the host name will be stripped of, e.g., \u0027www.google.com\u0027 will become \u0027google.com\u0027.",
                "simpleValueType": true,
                "name": "productionHostnameLookupTableStripWWW",
                "checkboxText": "Strip \u0027www.\u0027 from Page Hostname",
                "type": "CHECKBOX"
              },
              {
                "displayName": "Conditions",
                "name": "productionHostnameLookupTable",
                "simpleTableColumns": [
                  {
                    "selectItems": [
                      {
                        "displayValue": "equals",
                        "value": "equals"
                      },
                      {
                        "displayValue": "contains",
                        "value": "contains"
                      },
                      {
                        "displayValue": "starts with",
                        "value": "starts with"
                      },
                      {
                        "displayValue": "ends with",
                        "value": "ends with"
                      },
                      {
                        "displayValue": "does not equal",
                        "value": "does not equal"
                      },
                      {
                        "displayValue": "does not contain",
                        "value": "does not contain"
                      },
                      {
                        "displayValue": "does not start with",
                        "value": "does not start with"
                      },
                      {
                        "displayValue": "does not end with",
                        "value": "does not end with"
                      }
                    ],
                    "defaultValue": "equals",
                    "displayName": "Rule",
                    "name": "matchType",
                    "type": "SELECT",
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ]
                  },
                  {
                    "valueValidators": [],
                    "defaultValue": "",
                    "displayName": "Value",
                    "name": "value",
                    "type": "TEXT"
                  },
                  {
                    "defaultValue": "",
                    "displayName": "ID",
                    "name": "id",
                    "type": "TEXT",
                    "valueValidators": [
                      {
                        "type": "NON_EMPTY"
                      }
                    ]
                  }
                ],
                "type": "SIMPLE_TABLE"
              }
            ]
          }
        ]
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

// Enter your template code here.
// var log = require('logToConsole');
var getUrl = require('getUrl');

//log('data =', data);

// debug mode
if (data.inDebugMode === true && data.debugModeVar === true) {
  return data.debugModeID;
}
var row;

if (data.nonProductionCheckbox === true) {
  for (row in data.nonProductionLookupTable) {
    let rule = data.nonProductionLookupTable[row];
    if (evaluate(rule.variable, rule.matchType, rule.value)) { return rule.id; }
  }
}

if (data.productionAdvancedCheckbox === true) {
  for (row in data.productionAdvancedLookupTable) {
    let rule = data.productionAdvancedLookupTable[row];
    if (evaluate(rule.variable, rule.matchType, rule.value)) { return rule.id; }
  }
}
    
if (data.productionCustomLookupCheckbox === true) {
  for (row in data.productionCustomLookupTable) {
    let rule = data.productionCustomLookupTable[row];
    rule.variable = data.productionCustomLookupVariable;
    if (evaluate(rule.variable, rule.matchType, rule.value)) { return rule.id; }
  }
}
    
if (data.productionHostnameLookupCheckbox === true) {
  var hostname = getUrl("host");
  if (data.productionHostnameLookupTableStripWWW === true && hostname.substring(0, 4) === "www.") {
    hostname = hostname.substring(4, hostname.length); 
  }
  for (row in data.productionHostnameLookupTable) {
    let rule = data.productionHostnameLookupTable[row];
    rule.variable = hostname;    
    if (evaluate(rule.variable, rule.matchType, rule.value)) { return rule.id; }
  }
}
    




    
function evaluate (variable, matchType, value) {
  switch (matchType) {
    case "equals": if (variable === value) return true;
      break;
    case "contains": 
      if (typeof variable === "string" && variable.split(value).length > 1) return true; 
      break;
    case "starts with":
      if (typeof variable === "string") {
        let split = variable.split(value);
      	if (split.length > 1 && split[0] === "") return true; 
      }
      break;
    case "ends with":
      if (typeof variable === "string") {
        let split = variable.split(value);
      	if (split.length > 1 && split[split.length-1] === "") return true; 
      }
      break;
    case "does not equal": if (variable !== value) return true;
      break;
    case "does not contain":
      return !evaluate(variable, "contains", value);
    case "does not start with":
      return !evaluate(variable, "starts with", value);
    case "does not end with":
      return !evaluate(variable, "ends with", value);
  }
  
  var nvariable = variable*1, nvalue = value*1;
  if (nvariable !== null && nvalue !== null) {

    switch (matchType) {
      case "less than": return nvariable < nvalue;
      case "less than or equal to": return nvariable <= nvalue;
      case "greater than": return nvariable > nvalue;
      case "greater than or equal to": return nvariable >= nvalue;
    }
  }
  
  return false;
}

// Variables must return a value.
return undefined;


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 09/07/2019, 18:25:52


