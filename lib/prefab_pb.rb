# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: prefab.proto

require 'google/protobuf'


descriptor_data = "\n\x0cprefab.proto\x12\x06prefab\"W\n\x14\x43onfigServicePointer\x12\x12\n\nproject_id\x18\x01 \x01(\x03\x12\x13\n\x0bstart_at_id\x18\x02 \x01(\x03\x12\x16\n\x0eproject_env_id\x18\x03 \x01(\x03\"\xb1\x04\n\x0b\x43onfigValue\x12\r\n\x03int\x18\x01 \x01(\x03H\x00\x12\x10\n\x06string\x18\x02 \x01(\tH\x00\x12\x0f\n\x05\x62ytes\x18\x03 \x01(\x0cH\x00\x12\x10\n\x06\x64ouble\x18\x04 \x01(\x01H\x00\x12\x0e\n\x04\x62ool\x18\x05 \x01(\x08H\x00\x12\x31\n\x0fweighted_values\x18\x06 \x01(\x0b\x32\x16.prefab.WeightedValuesH\x00\x12\x33\n\x10limit_definition\x18\x07 \x01(\x0b\x32\x17.prefab.LimitDefinitionH\x00\x12%\n\tlog_level\x18\t \x01(\x0e\x32\x10.prefab.LogLevelH\x00\x12)\n\x0bstring_list\x18\n \x01(\x0b\x32\x12.prefab.StringListH\x00\x12%\n\tint_range\x18\x0b \x01(\x0b\x32\x10.prefab.IntRangeH\x00\x12$\n\x08provided\x18\x0c \x01(\x0b\x32\x10.prefab.ProvidedH\x00\x12\'\n\x08\x64uration\x18\x0f \x01(\x0b\x32\x13.prefab.IsoDurationH\x00\x12\x1c\n\x04json\x18\x10 \x01(\x0b\x32\x0c.prefab.JsonH\x00\x12 \n\x06schema\x18\x11 \x01(\x0b\x32\x0e.prefab.SchemaH\x00\x12\x19\n\x0c\x63onfidential\x18\r \x01(\x08H\x01\x88\x01\x01\x12\x19\n\x0c\x64\x65\x63rypt_with\x18\x0e \x01(\tH\x02\x88\x01\x01\x42\x06\n\x04typeB\x0f\n\r_confidentialB\x0f\n\r_decrypt_with\"\x14\n\x04Json\x12\x0c\n\x04json\x18\x01 \x01(\t\"!\n\x0bIsoDuration\x12\x12\n\ndefinition\x18\x01 \x01(\t\"b\n\x08Provided\x12+\n\x06source\x18\x01 \x01(\x0e\x32\x16.prefab.ProvidedSourceH\x00\x88\x01\x01\x12\x13\n\x06lookup\x18\x02 \x01(\tH\x01\x88\x01\x01\x42\t\n\x07_sourceB\t\n\x07_lookup\"B\n\x08IntRange\x12\x12\n\x05start\x18\x01 \x01(\x03H\x00\x88\x01\x01\x12\x10\n\x03\x65nd\x18\x02 \x01(\x03H\x01\x88\x01\x01\x42\x08\n\x06_startB\x06\n\x04_end\"\x1c\n\nStringList\x12\x0e\n\x06values\x18\x01 \x03(\t\"C\n\rWeightedValue\x12\x0e\n\x06weight\x18\x01 \x01(\x05\x12\"\n\x05value\x18\x02 \x01(\x0b\x32\x13.prefab.ConfigValue\"~\n\x0eWeightedValues\x12.\n\x0fweighted_values\x18\x01 \x03(\x0b\x32\x15.prefab.WeightedValue\x12\"\n\x15hash_by_property_name\x18\x02 \x01(\tH\x00\x88\x01\x01\x42\x18\n\x16_hash_by_property_name\"X\n\x0e\x41piKeyMetadata\x12\x13\n\x06key_id\x18\x01 \x01(\tH\x00\x88\x01\x01\x12\x14\n\x07user_id\x18\x03 \x01(\tH\x01\x88\x01\x01\x42\t\n\x07_key_idB\n\n\x08_user_idJ\x04\x08\x02\x10\x03\"\xa0\x02\n\x07\x43onfigs\x12\x1f\n\x07\x63onfigs\x18\x01 \x03(\x0b\x32\x0e.prefab.Config\x12<\n\x16\x63onfig_service_pointer\x18\x02 \x01(\x0b\x32\x1c.prefab.ConfigServicePointer\x12\x34\n\x0f\x61pikey_metadata\x18\x03 \x01(\x0b\x32\x16.prefab.ApiKeyMetadataH\x00\x88\x01\x01\x12\x30\n\x0f\x64\x65\x66\x61ult_context\x18\x04 \x01(\x0b\x32\x12.prefab.ContextSetH\x01\x88\x01\x01\x12\x17\n\nkeep_alive\x18\x05 \x01(\x08H\x02\x88\x01\x01\x42\x12\n\x10_apikey_metadataB\x12\n\x10_default_contextB\r\n\x0b_keep_alive\"\xa4\x04\n\x06\x43onfig\x12\n\n\x02id\x18\x01 \x01(\x03\x12\x12\n\nproject_id\x18\x02 \x01(\x03\x12\x0b\n\x03key\x18\x03 \x01(\t\x12%\n\nchanged_by\x18\x04 \x01(\x0b\x32\x11.prefab.ChangedBy\x12\x1f\n\x04rows\x18\x05 \x03(\x0b\x32\x11.prefab.ConfigRow\x12-\n\x10\x61llowable_values\x18\x06 \x03(\x0b\x32\x13.prefab.ConfigValue\x12\'\n\x0b\x63onfig_type\x18\x07 \x01(\x0e\x32\x12.prefab.ConfigType\x12\x15\n\x08\x64raft_id\x18\x08 \x01(\x03H\x00\x88\x01\x01\x12,\n\nvalue_type\x18\t \x01(\x0e\x32\x18.prefab.Config.ValueType\x12\x1a\n\x12send_to_client_sdk\x18\n \x01(\x08\x12\x17\n\nschema_key\x18\x0b \x01(\tH\x01\x88\x01\x01\"\xb6\x01\n\tValueType\x12\x16\n\x12NOT_SET_VALUE_TYPE\x10\x00\x12\x07\n\x03INT\x10\x01\x12\n\n\x06STRING\x10\x02\x12\t\n\x05\x42YTES\x10\x03\x12\n\n\x06\x44OUBLE\x10\x04\x12\x08\n\x04\x42OOL\x10\x05\x12\x14\n\x10LIMIT_DEFINITION\x10\x07\x12\r\n\tLOG_LEVEL\x10\t\x12\x0f\n\x0bSTRING_LIST\x10\n\x12\r\n\tINT_RANGE\x10\x0b\x12\x0c\n\x08\x44URATION\x10\x0c\x12\x08\n\x04JSON\x10\rB\x0b\n\t_draft_idB\r\n\x0b_schema_key\"?\n\tChangedBy\x12\x0f\n\x07user_id\x18\x01 \x01(\x03\x12\r\n\x05\x65mail\x18\x02 \x01(\t\x12\x12\n\napi_key_id\x18\x03 \x01(\t\"\xe4\x01\n\tConfigRow\x12\x1b\n\x0eproject_env_id\x18\x01 \x01(\x03H\x00\x88\x01\x01\x12(\n\x06values\x18\x02 \x03(\x0b\x32\x18.prefab.ConditionalValue\x12\x35\n\nproperties\x18\x03 \x03(\x0b\x32!.prefab.ConfigRow.PropertiesEntry\x1a\x46\n\x0fPropertiesEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12\"\n\x05value\x18\x02 \x01(\x0b\x32\x13.prefab.ConfigValue:\x02\x38\x01\x42\x11\n\x0f_project_env_id\"[\n\x10\x43onditionalValue\x12#\n\x08\x63riteria\x18\x01 \x03(\x0b\x32\x11.prefab.Criterion\x12\"\n\x05value\x18\x02 \x01(\x0b\x32\x13.prefab.ConfigValue\"\x96\x06\n\tCriterion\x12\x15\n\rproperty_name\x18\x01 \x01(\t\x12\x35\n\x08operator\x18\x02 \x01(\x0e\x32#.prefab.Criterion.CriterionOperator\x12+\n\x0evalue_to_match\x18\x03 \x01(\x0b\x32\x13.prefab.ConfigValue\"\x8d\x05\n\x11\x43riterionOperator\x12\x0b\n\x07NOT_SET\x10\x00\x12\x11\n\rLOOKUP_KEY_IN\x10\x01\x12\x15\n\x11LOOKUP_KEY_NOT_IN\x10\x02\x12\n\n\x06IN_SEG\x10\x03\x12\x0e\n\nNOT_IN_SEG\x10\x04\x12\x0f\n\x0b\x41LWAYS_TRUE\x10\x05\x12\x12\n\x0ePROP_IS_ONE_OF\x10\x06\x12\x16\n\x12PROP_IS_NOT_ONE_OF\x10\x07\x12\x19\n\x15PROP_ENDS_WITH_ONE_OF\x10\x08\x12!\n\x1dPROP_DOES_NOT_END_WITH_ONE_OF\x10\t\x12\x16\n\x12HIERARCHICAL_MATCH\x10\n\x12\x10\n\x0cIN_INT_RANGE\x10\x0b\x12\x1b\n\x17PROP_STARTS_WITH_ONE_OF\x10\x0c\x12#\n\x1fPROP_DOES_NOT_START_WITH_ONE_OF\x10\r\x12\x18\n\x14PROP_CONTAINS_ONE_OF\x10\x0e\x12 \n\x1cPROP_DOES_NOT_CONTAIN_ONE_OF\x10\x0f\x12\x12\n\x0ePROP_LESS_THAN\x10\x10\x12\x1b\n\x17PROP_LESS_THAN_OR_EQUAL\x10\x11\x12\x15\n\x11PROP_GREATER_THAN\x10\x12\x12\x1e\n\x1aPROP_GREATER_THAN_OR_EQUAL\x10\x13\x12\x0f\n\x0bPROP_BEFORE\x10\x14\x12\x0e\n\nPROP_AFTER\x10\x15\x12\x10\n\x0cPROP_MATCHES\x10\x16\x12\x17\n\x13PROP_DOES_NOT_MATCH\x10\x17\x12\x19\n\x15PROP_SEMVER_LESS_THAN\x10\x18\x12\x15\n\x11PROP_SEMVER_EQUAL\x10\x19\x12\x1c\n\x18PROP_SEMVER_GREATER_THAN\x10\x1a\"\x89\x01\n\x07Loggers\x12\x1f\n\x07loggers\x18\x01 \x03(\x0b\x32\x0e.prefab.Logger\x12\x10\n\x08start_at\x18\x02 \x01(\x03\x12\x0e\n\x06\x65nd_at\x18\x03 \x01(\x03\x12\x15\n\rinstance_hash\x18\x04 \x01(\t\x12\x16\n\tnamespace\x18\x05 \x01(\tH\x00\x88\x01\x01\x42\x0c\n\n_namespace\"\xd9\x01\n\x06Logger\x12\x13\n\x0blogger_name\x18\x01 \x01(\t\x12\x13\n\x06traces\x18\x02 \x01(\x03H\x00\x88\x01\x01\x12\x13\n\x06\x64\x65\x62ugs\x18\x03 \x01(\x03H\x01\x88\x01\x01\x12\x12\n\x05infos\x18\x04 \x01(\x03H\x02\x88\x01\x01\x12\x12\n\x05warns\x18\x05 \x01(\x03H\x03\x88\x01\x01\x12\x13\n\x06\x65rrors\x18\x06 \x01(\x03H\x04\x88\x01\x01\x12\x13\n\x06\x66\x61tals\x18\x07 \x01(\x03H\x05\x88\x01\x01\x42\t\n\x07_tracesB\t\n\x07_debugsB\x08\n\x06_infosB\x08\n\x06_warnsB\t\n\x07_errorsB\t\n\x07_fatals\"\x16\n\x14LoggerReportResponse\"\xdb\x03\n\rLimitResponse\x12\x0e\n\x06passed\x18\x01 \x01(\x08\x12\x12\n\nexpires_at\x18\x02 \x01(\x03\x12\x16\n\x0e\x65nforced_group\x18\x03 \x01(\t\x12\x16\n\x0e\x63urrent_bucket\x18\x04 \x01(\x03\x12\x14\n\x0cpolicy_group\x18\x05 \x01(\t\x12;\n\x0bpolicy_name\x18\x06 \x01(\x0e\x32&.prefab.LimitResponse.LimitPolicyNames\x12\x14\n\x0cpolicy_limit\x18\x07 \x01(\x05\x12\x0e\n\x06\x61mount\x18\x08 \x01(\x03\x12\x16\n\x0elimit_reset_at\x18\t \x01(\x03\x12\x39\n\x0csafety_level\x18\n \x01(\x0e\x32#.prefab.LimitDefinition.SafetyLevel\"\xa9\x01\n\x10LimitPolicyNames\x12\x0b\n\x07NOT_SET\x10\x00\x12\x14\n\x10SECONDLY_ROLLING\x10\x01\x12\x14\n\x10MINUTELY_ROLLING\x10\x03\x12\x12\n\x0eHOURLY_ROLLING\x10\x05\x12\x11\n\rDAILY_ROLLING\x10\x07\x12\x13\n\x0fMONTHLY_ROLLING\x10\x08\x12\x0c\n\x08INFINITE\x10\t\x12\x12\n\x0eYEARLY_ROLLING\x10\n\"\x99\x02\n\x0cLimitRequest\x12\x12\n\naccount_id\x18\x01 \x01(\x03\x12\x16\n\x0e\x61\x63quire_amount\x18\x02 \x01(\x05\x12\x0e\n\x06groups\x18\x03 \x03(\t\x12:\n\x0elimit_combiner\x18\x04 \x01(\x0e\x32\".prefab.LimitRequest.LimitCombiner\x12\x1e\n\x16\x61llow_partial_response\x18\x05 \x01(\x08\x12\x39\n\x0csafety_level\x18\x06 \x01(\x0e\x32#.prefab.LimitDefinition.SafetyLevel\"6\n\rLimitCombiner\x12\x0b\n\x07NOT_SET\x10\x00\x12\x0b\n\x07MINIMUM\x10\x01\x12\x0b\n\x07MAXIMUM\x10\x02\"/\n\nContextSet\x12!\n\x08\x63ontexts\x18\x01 \x03(\x0b\x32\x0f.prefab.Context\"\x96\x01\n\x07\x43ontext\x12\x11\n\x04type\x18\x01 \x01(\tH\x00\x88\x01\x01\x12+\n\x06values\x18\x02 \x03(\x0b\x32\x1b.prefab.Context.ValuesEntry\x1a\x42\n\x0bValuesEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12\"\n\x05value\x18\x02 \x01(\x0b\x32\x13.prefab.ConfigValue:\x02\x38\x01\x42\x07\n\x05_type\"\x93\x01\n\x08Identity\x12\x13\n\x06lookup\x18\x01 \x01(\tH\x00\x88\x01\x01\x12\x34\n\nattributes\x18\x02 \x03(\x0b\x32 .prefab.Identity.AttributesEntry\x1a\x31\n\x0f\x41ttributesEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12\r\n\x05value\x18\x02 \x01(\t:\x02\x38\x01\x42\t\n\x07_lookup\"\xd6\x02\n\x18\x43onfigEvaluationMetaData\x12\x1d\n\x10\x63onfig_row_index\x18\x01 \x01(\x03H\x00\x88\x01\x01\x12$\n\x17\x63onditional_value_index\x18\x02 \x01(\x03H\x01\x88\x01\x01\x12!\n\x14weighted_value_index\x18\x03 \x01(\x03H\x02\x88\x01\x01\x12%\n\x04type\x18\x04 \x01(\x0e\x32\x12.prefab.ConfigTypeH\x03\x88\x01\x01\x12\x0f\n\x02id\x18\x05 \x01(\x03H\x04\x88\x01\x01\x12\x31\n\nvalue_type\x18\x06 \x01(\x0e\x32\x18.prefab.Config.ValueTypeH\x05\x88\x01\x01\x42\x13\n\x11_config_row_indexB\x1a\n\x18_conditional_value_indexB\x17\n\x15_weighted_value_indexB\x07\n\x05_typeB\x05\n\x03_idB\r\n\x0b_value_type\"\x8b\x03\n\x11\x43lientConfigValue\x12\r\n\x03int\x18\x01 \x01(\x03H\x00\x12\x10\n\x06string\x18\x02 \x01(\tH\x00\x12\x10\n\x06\x64ouble\x18\x03 \x01(\x01H\x00\x12\x0e\n\x04\x62ool\x18\x04 \x01(\x08H\x00\x12%\n\tlog_level\x18\x05 \x01(\x0e\x32\x10.prefab.LogLevelH\x00\x12)\n\x0bstring_list\x18\x07 \x01(\x0b\x32\x12.prefab.StringListH\x00\x12%\n\tint_range\x18\x08 \x01(\x0b\x32\x10.prefab.IntRangeH\x00\x12*\n\x08\x64uration\x18\t \x01(\x0b\x32\x16.prefab.ClientDurationH\x00\x12\x1c\n\x04json\x18\n \x01(\x0b\x32\x0c.prefab.JsonH\x00\x12I\n\x1a\x63onfig_evaluation_metadata\x18\x06 \x01(\x0b\x32 .prefab.ConfigEvaluationMetaDataH\x01\x88\x01\x01\x42\x06\n\x04typeB\x1d\n\x1b_config_evaluation_metadata\"D\n\x0e\x43lientDuration\x12\x0f\n\x07seconds\x18\x01 \x01(\x03\x12\r\n\x05nanos\x18\x02 \x01(\x05\x12\x12\n\ndefinition\x18\x03 \x01(\t\"\xa4\x02\n\x11\x43onfigEvaluations\x12\x35\n\x06values\x18\x01 \x03(\x0b\x32%.prefab.ConfigEvaluations.ValuesEntry\x12\x34\n\x0f\x61pikey_metadata\x18\x02 \x01(\x0b\x32\x16.prefab.ApiKeyMetadataH\x00\x88\x01\x01\x12\x30\n\x0f\x64\x65\x66\x61ult_context\x18\x03 \x01(\x0b\x32\x12.prefab.ContextSetH\x01\x88\x01\x01\x1aH\n\x0bValuesEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12(\n\x05value\x18\x02 \x01(\x0b\x32\x19.prefab.ClientConfigValue:\x02\x38\x01\x42\x12\n\x10_apikey_metadataB\x12\n\x10_default_context\"\xa8\x02\n\x0fLimitDefinition\x12;\n\x0bpolicy_name\x18\x02 \x01(\x0e\x32&.prefab.LimitResponse.LimitPolicyNames\x12\r\n\x05limit\x18\x03 \x01(\x05\x12\r\n\x05\x62urst\x18\x04 \x01(\x05\x12\x12\n\naccount_id\x18\x05 \x01(\x03\x12\x15\n\rlast_modified\x18\x06 \x01(\x03\x12\x12\n\nreturnable\x18\x07 \x01(\x08\x12\x39\n\x0csafety_level\x18\x08 \x01(\x0e\x32#.prefab.LimitDefinition.SafetyLevel\"@\n\x0bSafetyLevel\x12\x0b\n\x07NOT_SET\x10\x00\x12\x12\n\x0eL4_BEST_EFFORT\x10\x04\x12\x10\n\x0cL5_BOMBPROOF\x10\x05\"@\n\x10LimitDefinitions\x12,\n\x0b\x64\x65\x66initions\x18\x01 \x03(\x0b\x32\x17.prefab.LimitDefinition\"\x8a\x01\n\x0f\x42ufferedRequest\x12\x12\n\naccount_id\x18\x01 \x01(\x03\x12\x0e\n\x06method\x18\x02 \x01(\t\x12\x0b\n\x03uri\x18\x03 \x01(\t\x12\x0c\n\x04\x62ody\x18\x04 \x01(\t\x12\x14\n\x0climit_groups\x18\x05 \x03(\t\x12\x14\n\x0c\x63ontent_type\x18\x06 \x01(\t\x12\x0c\n\x04\x66ifo\x18\x07 \x01(\x08\"\x94\x01\n\x0c\x42\x61tchRequest\x12\x12\n\naccount_id\x18\x01 \x01(\x03\x12\x0e\n\x06method\x18\x02 \x01(\t\x12\x0b\n\x03uri\x18\x03 \x01(\t\x12\x0c\n\x04\x62ody\x18\x04 \x01(\t\x12\x14\n\x0climit_groups\x18\x05 \x03(\t\x12\x16\n\x0e\x62\x61tch_template\x18\x06 \x01(\t\x12\x17\n\x0f\x62\x61tch_separator\x18\x07 \x01(\t\" \n\rBasicResponse\x12\x0f\n\x07message\x18\x01 \x01(\t\"3\n\x10\x43reationResponse\x12\x0f\n\x07message\x18\x01 \x01(\t\x12\x0e\n\x06new_id\x18\x02 \x01(\x03\"h\n\x07IdBlock\x12\x12\n\nproject_id\x18\x01 \x01(\x03\x12\x16\n\x0eproject_env_id\x18\x02 \x01(\x03\x12\x15\n\rsequence_name\x18\x03 \x01(\t\x12\r\n\x05start\x18\x04 \x01(\x03\x12\x0b\n\x03\x65nd\x18\x05 \x01(\x03\"a\n\x0eIdBlockRequest\x12\x12\n\nproject_id\x18\x01 \x01(\x03\x12\x16\n\x0eproject_env_id\x18\x02 \x01(\x03\x12\x15\n\rsequence_name\x18\x03 \x01(\t\x12\x0c\n\x04size\x18\x04 \x01(\x03\"\x8a\x01\n\x0c\x43ontextShape\x12\x0c\n\x04name\x18\x01 \x01(\t\x12\x39\n\x0b\x66ield_types\x18\x02 \x03(\x0b\x32$.prefab.ContextShape.FieldTypesEntry\x1a\x31\n\x0f\x46ieldTypesEntry\x12\x0b\n\x03key\x18\x01 \x01(\t\x12\r\n\x05value\x18\x02 \x01(\x05:\x02\x38\x01\"[\n\rContextShapes\x12$\n\x06shapes\x18\x01 \x03(\x0b\x32\x14.prefab.ContextShape\x12\x16\n\tnamespace\x18\x02 \x01(\tH\x00\x88\x01\x01\x42\x0c\n\n_namespace\"C\n\rEvaluatedKeys\x12\x0c\n\x04keys\x18\x01 \x03(\t\x12\x16\n\tnamespace\x18\x02 \x01(\tH\x00\x88\x01\x01\x42\x0c\n\n_namespace\"\x93\x01\n\x0f\x45valuatedConfig\x12\x0b\n\x03key\x18\x01 \x01(\t\x12\x16\n\x0e\x63onfig_version\x18\x02 \x01(\x03\x12#\n\x06result\x18\x03 \x01(\x0b\x32\x13.prefab.ConfigValue\x12#\n\x07\x63ontext\x18\x04 \x01(\x0b\x32\x12.prefab.ContextSet\x12\x11\n\ttimestamp\x18\x05 \x01(\x03\"<\n\x10\x45valuatedConfigs\x12(\n\x07\x63onfigs\x18\x01 \x03(\x0b\x32\x17.prefab.EvaluatedConfig\"\xc4\x03\n\x17\x43onfigEvaluationCounter\x12\r\n\x05\x63ount\x18\x01 \x01(\x03\x12\x16\n\tconfig_id\x18\x02 \x01(\x03H\x00\x88\x01\x01\x12\x1b\n\x0eselected_index\x18\x03 \x01(\rH\x01\x88\x01\x01\x12\x30\n\x0eselected_value\x18\x04 \x01(\x0b\x32\x13.prefab.ConfigValueH\x02\x88\x01\x01\x12\x1d\n\x10\x63onfig_row_index\x18\x05 \x01(\rH\x03\x88\x01\x01\x12$\n\x17\x63onditional_value_index\x18\x06 \x01(\rH\x04\x88\x01\x01\x12!\n\x14weighted_value_index\x18\x07 \x01(\rH\x05\x88\x01\x01\x12\x36\n\x06reason\x18\x08 \x01(\x0e\x32&.prefab.ConfigEvaluationCounter.Reason\"\x15\n\x06Reason\x12\x0b\n\x07UNKNOWN\x10\x00\x42\x0c\n\n_config_idB\x11\n\x0f_selected_indexB\x11\n\x0f_selected_valueB\x13\n\x11_config_row_indexB\x1a\n\x18_conditional_value_indexB\x17\n\x15_weighted_value_index\"{\n\x17\x43onfigEvaluationSummary\x12\x0b\n\x03key\x18\x01 \x01(\t\x12 \n\x04type\x18\x02 \x01(\x0e\x32\x12.prefab.ConfigType\x12\x31\n\x08\x63ounters\x18\x03 \x03(\x0b\x32\x1f.prefab.ConfigEvaluationCounter\"k\n\x19\x43onfigEvaluationSummaries\x12\r\n\x05start\x18\x01 \x01(\x03\x12\x0b\n\x03\x65nd\x18\x02 \x01(\x03\x12\x32\n\tsummaries\x18\x03 \x03(\x0b\x32\x1f.prefab.ConfigEvaluationSummary\"Z\n\x15LoggersTelemetryEvent\x12\x1f\n\x07loggers\x18\x01 \x03(\x0b\x32\x0e.prefab.Logger\x12\x10\n\x08start_at\x18\x02 \x01(\x03\x12\x0e\n\x06\x65nd_at\x18\x03 \x01(\x03\"\x98\x02\n\x0eTelemetryEvent\x12\x36\n\tsummaries\x18\x02 \x01(\x0b\x32!.prefab.ConfigEvaluationSummariesH\x00\x12\x33\n\x10\x65xample_contexts\x18\x03 \x01(\x0b\x32\x17.prefab.ExampleContextsH\x00\x12+\n\x0c\x63lient_stats\x18\x04 \x01(\x0b\x32\x13.prefab.ClientStatsH\x00\x12\x30\n\x07loggers\x18\x05 \x01(\x0b\x32\x1d.prefab.LoggersTelemetryEventH\x00\x12/\n\x0e\x63ontext_shapes\x18\x06 \x01(\x0b\x32\x15.prefab.ContextShapesH\x00\x42\t\n\x07payload\"P\n\x0fTelemetryEvents\x12\x15\n\rinstance_hash\x18\x01 \x01(\t\x12&\n\x06\x65vents\x18\x02 \x03(\x0b\x32\x16.prefab.TelemetryEvent\"*\n\x17TelemetryEventsResponse\x12\x0f\n\x07success\x18\x01 \x01(\x08\";\n\x0f\x45xampleContexts\x12(\n\x08\x65xamples\x18\x01 \x03(\x0b\x32\x16.prefab.ExampleContext\"K\n\x0e\x45xampleContext\x12\x11\n\ttimestamp\x18\x01 \x01(\x03\x12&\n\ncontextSet\x18\x02 \x01(\x0b\x32\x12.prefab.ContextSet\"F\n\x0b\x43lientStats\x12\r\n\x05start\x18\x01 \x01(\x03\x12\x0b\n\x03\x65nd\x18\x02 \x01(\x03\x12\x1b\n\x13\x64ropped_event_count\x18\x03 \x01(\x04\"}\n\x06Schema\x12\x0e\n\x06schema\x18\x01 \x01(\t\x12.\n\x0bschema_type\x18\x02 \x01(\x0e\x32\x19.prefab.Schema.SchemaType\"3\n\nSchemaType\x12\x0b\n\x07UNKNOWN\x10\x00\x12\x07\n\x03ZOD\x10\x01\x12\x0f\n\x0bJSON_SCHEMA\x10\x02*:\n\x0eProvidedSource\x12\x1b\n\x17PROVIDED_SOURCE_NOT_SET\x10\x00\x12\x0b\n\x07\x45NV_VAR\x10\x01*\x8e\x01\n\nConfigType\x12\x17\n\x13NOT_SET_CONFIG_TYPE\x10\x00\x12\n\n\x06\x43ONFIG\x10\x01\x12\x10\n\x0c\x46\x45\x41TURE_FLAG\x10\x02\x12\r\n\tLOG_LEVEL\x10\x03\x12\x0b\n\x07SEGMENT\x10\x04\x12\x14\n\x10LIMIT_DEFINITION\x10\x05\x12\x0b\n\x07\x44\x45LETED\x10\x06\x12\n\n\x06SCHEMA\x10\x07*a\n\x08LogLevel\x12\x15\n\x11NOT_SET_LOG_LEVEL\x10\x00\x12\t\n\x05TRACE\x10\x01\x12\t\n\x05\x44\x45\x42UG\x10\x02\x12\x08\n\x04INFO\x10\x03\x12\x08\n\x04WARN\x10\x05\x12\t\n\x05\x45RROR\x10\x06\x12\t\n\x05\x46\x41TAL\x10\t*G\n\tOnFailure\x12\x0b\n\x07NOT_SET\x10\x00\x12\x10\n\x0cLOG_AND_PASS\x10\x01\x12\x10\n\x0cLOG_AND_FAIL\x10\x02\x12\t\n\x05THROW\x10\x03\x42L\n\x13\x63loud.prefab.domainB\x06PrefabZ-github.com/prefab-cloud/prefab-cloud-go/protob\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module PrefabProto
  ConfigServicePointer = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigServicePointer").msgclass
  ConfigValue = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigValue").msgclass
  Json = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Json").msgclass
  IsoDuration = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.IsoDuration").msgclass
  Provided = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Provided").msgclass
  IntRange = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.IntRange").msgclass
  StringList = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.StringList").msgclass
  WeightedValue = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.WeightedValue").msgclass
  WeightedValues = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.WeightedValues").msgclass
  ApiKeyMetadata = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ApiKeyMetadata").msgclass
  Configs = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Configs").msgclass
  Config = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Config").msgclass
  Config::ValueType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Config.ValueType").enummodule
  ChangedBy = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ChangedBy").msgclass
  ConfigRow = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigRow").msgclass
  ConditionalValue = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConditionalValue").msgclass
  Criterion = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Criterion").msgclass
  Criterion::CriterionOperator = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Criterion.CriterionOperator").enummodule
  Loggers = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Loggers").msgclass
  Logger = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Logger").msgclass
  LoggerReportResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LoggerReportResponse").msgclass
  LimitResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitResponse").msgclass
  LimitResponse::LimitPolicyNames = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitResponse.LimitPolicyNames").enummodule
  LimitRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitRequest").msgclass
  LimitRequest::LimitCombiner = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitRequest.LimitCombiner").enummodule
  ContextSet = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ContextSet").msgclass
  Context = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Context").msgclass
  Identity = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Identity").msgclass
  ConfigEvaluationMetaData = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigEvaluationMetaData").msgclass
  ClientConfigValue = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ClientConfigValue").msgclass
  ClientDuration = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ClientDuration").msgclass
  ConfigEvaluations = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigEvaluations").msgclass
  LimitDefinition = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitDefinition").msgclass
  LimitDefinition::SafetyLevel = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitDefinition.SafetyLevel").enummodule
  LimitDefinitions = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LimitDefinitions").msgclass
  BufferedRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.BufferedRequest").msgclass
  BatchRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.BatchRequest").msgclass
  BasicResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.BasicResponse").msgclass
  CreationResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.CreationResponse").msgclass
  IdBlock = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.IdBlock").msgclass
  IdBlockRequest = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.IdBlockRequest").msgclass
  ContextShape = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ContextShape").msgclass
  ContextShapes = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ContextShapes").msgclass
  EvaluatedKeys = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.EvaluatedKeys").msgclass
  EvaluatedConfig = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.EvaluatedConfig").msgclass
  EvaluatedConfigs = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.EvaluatedConfigs").msgclass
  ConfigEvaluationCounter = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigEvaluationCounter").msgclass
  ConfigEvaluationCounter::Reason = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigEvaluationCounter.Reason").enummodule
  ConfigEvaluationSummary = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigEvaluationSummary").msgclass
  ConfigEvaluationSummaries = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigEvaluationSummaries").msgclass
  LoggersTelemetryEvent = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LoggersTelemetryEvent").msgclass
  TelemetryEvent = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.TelemetryEvent").msgclass
  TelemetryEvents = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.TelemetryEvents").msgclass
  TelemetryEventsResponse = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.TelemetryEventsResponse").msgclass
  ExampleContexts = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ExampleContexts").msgclass
  ExampleContext = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ExampleContext").msgclass
  ClientStats = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ClientStats").msgclass
  Schema = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Schema").msgclass
  Schema::SchemaType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.Schema.SchemaType").enummodule
  ProvidedSource = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ProvidedSource").enummodule
  ConfigType = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.ConfigType").enummodule
  LogLevel = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.LogLevel").enummodule
  OnFailure = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("prefab.OnFailure").enummodule
end
