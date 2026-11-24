// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_setting.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetAppSettingCollection on Isar {
  IsarCollection<AppSetting> get appSettings => this.collection();
}

const AppSettingSchema = CollectionSchema(
  name: r'AppSetting',
  id: -948817443998796339,
  properties: {
    r'activeProfileId': PropertySchema(
      id: 0,
      name: r'activeProfileId',
      type: IsarType.long,
    ),
    r'aiApiKey': PropertySchema(
      id: 1,
      name: r'aiApiKey',
      type: IsarType.string,
    ),
    r'aiBaseUrl': PropertySchema(
      id: 2,
      name: r'aiBaseUrl',
      type: IsarType.string,
    ),
    r'aiBuiltinModelId': PropertySchema(
      id: 3,
      name: r'aiBuiltinModelId',
      type: IsarType.string,
    ),
    r'aiLicenseCode': PropertySchema(
      id: 4,
      name: r'aiLicenseCode',
      type: IsarType.string,
    ),
    r'aiModel': PropertySchema(
      id: 5,
      name: r'aiModel',
      type: IsarType.string,
    ),
    r'aiModelCacheAt': PropertySchema(
      id: 6,
      name: r'aiModelCacheAt',
      type: IsarType.dateTime,
    ),
    r'aiModelCacheJson': PropertySchema(
      id: 7,
      name: r'aiModelCacheJson',
      type: IsarType.string,
    ),
    r'aiProviderId': PropertySchema(
      id: 8,
      name: r'aiProviderId',
      type: IsarType.string,
    ),
    r'aiSystemPrompt': PropertySchema(
      id: 9,
      name: r'aiSystemPrompt',
      type: IsarType.string,
    ),
    r'aiThinkingLevel': PropertySchema(
      id: 10,
      name: r'aiThinkingLevel',
      type: IsarType.long,
    ),
    r'aiVisionEnabled': PropertySchema(
      id: 11,
      name: r'aiVisionEnabled',
      type: IsarType.bool,
    ),
    r'chatSessionId': PropertySchema(
      id: 12,
      name: r'chatSessionId',
      type: IsarType.long,
    ),
    r'contextWindowTokens': PropertySchema(
      id: 13,
      name: r'contextWindowTokens',
      type: IsarType.long,
    ),
    r'defaultUnitPrice': PropertySchema(
      id: 14,
      name: r'defaultUnitPrice',
      type: IsarType.double,
    ),
    r'lastBackupMs': PropertySchema(
      id: 15,
      name: r'lastBackupMs',
      type: IsarType.long,
    ),
    r'reportFontScale': PropertySchema(
      id: 16,
      name: r'reportFontScale',
      type: IsarType.double,
    ),
    r'reportGroupBy': PropertySchema(
      id: 17,
      name: r'reportGroupBy',
      type: IsarType.long,
    ),
    r'reportShowPhoto': PropertySchema(
      id: 18,
      name: r'reportShowPhoto',
      type: IsarType.bool,
    ),
    r'reportSubtitle': PropertySchema(
      id: 19,
      name: r'reportSubtitle',
      type: IsarType.string,
    ),
    r'reportTemplate': PropertySchema(
      id: 20,
      name: r'reportTemplate',
      type: IsarType.long,
    ),
    r'reportTitle': PropertySchema(
      id: 21,
      name: r'reportTitle',
      type: IsarType.string,
    ),
    r'themeModeIndex': PropertySchema(
      id: 22,
      name: r'themeModeIndex',
      type: IsarType.long,
    ),
    r'webdavDir': PropertySchema(
      id: 23,
      name: r'webdavDir',
      type: IsarType.string,
    ),
    r'webdavEnabled': PropertySchema(
      id: 24,
      name: r'webdavEnabled',
      type: IsarType.bool,
    ),
    r'webdavPass': PropertySchema(
      id: 25,
      name: r'webdavPass',
      type: IsarType.string,
    ),
    r'webdavUrl': PropertySchema(
      id: 26,
      name: r'webdavUrl',
      type: IsarType.string,
    ),
    r'webdavUser': PropertySchema(
      id: 27,
      name: r'webdavUser',
      type: IsarType.string,
    )
  },
  estimateSize: _appSettingEstimateSize,
  serialize: _appSettingSerialize,
  deserialize: _appSettingDeserialize,
  deserializeProp: _appSettingDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _appSettingGetId,
  getLinks: _appSettingGetLinks,
  attach: _appSettingAttach,
  version: '3.4.1',
);

int _appSettingEstimateSize(
  AppSetting object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.aiApiKey.length * 3;
  bytesCount += 3 + object.aiBaseUrl.length * 3;
  bytesCount += 3 + object.aiBuiltinModelId.length * 3;
  bytesCount += 3 + object.aiLicenseCode.length * 3;
  bytesCount += 3 + object.aiModel.length * 3;
  bytesCount += 3 + object.aiModelCacheJson.length * 3;
  bytesCount += 3 + object.aiProviderId.length * 3;
  bytesCount += 3 + object.aiSystemPrompt.length * 3;
  bytesCount += 3 + object.reportSubtitle.length * 3;
  bytesCount += 3 + object.reportTitle.length * 3;
  bytesCount += 3 + object.webdavDir.length * 3;
  bytesCount += 3 + object.webdavPass.length * 3;
  bytesCount += 3 + object.webdavUrl.length * 3;
  bytesCount += 3 + object.webdavUser.length * 3;
  return bytesCount;
}

void _appSettingSerialize(
  AppSetting object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.activeProfileId);
  writer.writeString(offsets[1], object.aiApiKey);
  writer.writeString(offsets[2], object.aiBaseUrl);
  writer.writeString(offsets[3], object.aiBuiltinModelId);
  writer.writeString(offsets[4], object.aiLicenseCode);
  writer.writeString(offsets[5], object.aiModel);
  writer.writeDateTime(offsets[6], object.aiModelCacheAt);
  writer.writeString(offsets[7], object.aiModelCacheJson);
  writer.writeString(offsets[8], object.aiProviderId);
  writer.writeString(offsets[9], object.aiSystemPrompt);
  writer.writeLong(offsets[10], object.aiThinkingLevel);
  writer.writeBool(offsets[11], object.aiVisionEnabled);
  writer.writeLong(offsets[12], object.chatSessionId);
  writer.writeLong(offsets[13], object.contextWindowTokens);
  writer.writeDouble(offsets[14], object.defaultUnitPrice);
  writer.writeLong(offsets[15], object.lastBackupMs);
  writer.writeDouble(offsets[16], object.reportFontScale);
  writer.writeLong(offsets[17], object.reportGroupBy);
  writer.writeBool(offsets[18], object.reportShowPhoto);
  writer.writeString(offsets[19], object.reportSubtitle);
  writer.writeLong(offsets[20], object.reportTemplate);
  writer.writeString(offsets[21], object.reportTitle);
  writer.writeLong(offsets[22], object.themeModeIndex);
  writer.writeString(offsets[23], object.webdavDir);
  writer.writeBool(offsets[24], object.webdavEnabled);
  writer.writeString(offsets[25], object.webdavPass);
  writer.writeString(offsets[26], object.webdavUrl);
  writer.writeString(offsets[27], object.webdavUser);
}

AppSetting _appSettingDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = AppSetting();
  object.activeProfileId = reader.readLong(offsets[0]);
  object.aiApiKey = reader.readString(offsets[1]);
  object.aiBaseUrl = reader.readString(offsets[2]);
  object.aiBuiltinModelId = reader.readString(offsets[3]);
  object.aiLicenseCode = reader.readString(offsets[4]);
  object.aiModel = reader.readString(offsets[5]);
  object.aiModelCacheAt = reader.readDateTimeOrNull(offsets[6]);
  object.aiModelCacheJson = reader.readString(offsets[7]);
  object.aiProviderId = reader.readString(offsets[8]);
  object.aiSystemPrompt = reader.readString(offsets[9]);
  object.aiThinkingLevel = reader.readLong(offsets[10]);
  object.aiVisionEnabled = reader.readBool(offsets[11]);
  object.chatSessionId = reader.readLong(offsets[12]);
  object.contextWindowTokens = reader.readLong(offsets[13]);
  object.defaultUnitPrice = reader.readDouble(offsets[14]);
  object.id = id;
  object.lastBackupMs = reader.readLong(offsets[15]);
  object.reportFontScale = reader.readDouble(offsets[16]);
  object.reportGroupBy = reader.readLong(offsets[17]);
  object.reportShowPhoto = reader.readBool(offsets[18]);
  object.reportSubtitle = reader.readString(offsets[19]);
  object.reportTemplate = reader.readLong(offsets[20]);
  object.reportTitle = reader.readString(offsets[21]);
  object.themeModeIndex = reader.readLong(offsets[22]);
  object.webdavDir = reader.readString(offsets[23]);
  object.webdavEnabled = reader.readBool(offsets[24]);
  object.webdavPass = reader.readString(offsets[25]);
  object.webdavUrl = reader.readString(offsets[26]);
  object.webdavUser = reader.readString(offsets[27]);
  return object;
}

P _appSettingDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readString(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readLong(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readLong(offset)) as P;
    case 13:
      return (reader.readLong(offset)) as P;
    case 14:
      return (reader.readDouble(offset)) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    case 16:
      return (reader.readDouble(offset)) as P;
    case 17:
      return (reader.readLong(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readString(offset)) as P;
    case 20:
      return (reader.readLong(offset)) as P;
    case 21:
      return (reader.readString(offset)) as P;
    case 22:
      return (reader.readLong(offset)) as P;
    case 23:
      return (reader.readString(offset)) as P;
    case 24:
      return (reader.readBool(offset)) as P;
    case 25:
      return (reader.readString(offset)) as P;
    case 26:
      return (reader.readString(offset)) as P;
    case 27:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _appSettingGetId(AppSetting object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _appSettingGetLinks(AppSetting object) {
  return [];
}

void _appSettingAttach(IsarCollection<dynamic> col, Id id, AppSetting object) {
  object.id = id;
}

extension AppSettingQueryWhereSort
    on QueryBuilder<AppSetting, AppSetting, QWhere> {
  QueryBuilder<AppSetting, AppSetting, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension AppSettingQueryWhere
    on QueryBuilder<AppSetting, AppSetting, QWhereClause> {
  QueryBuilder<AppSetting, AppSetting, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension AppSettingQueryFilter
    on QueryBuilder<AppSetting, AppSetting, QFilterCondition> {
  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      activeProfileIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'activeProfileId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      activeProfileIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'activeProfileId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      activeProfileIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'activeProfileId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      activeProfileIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'activeProfileId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiApiKeyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiApiKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiApiKeyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiApiKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiApiKeyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiApiKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiApiKeyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiApiKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiApiKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiApiKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiApiKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiApiKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiApiKeyContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiApiKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiApiKeyMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiApiKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiApiKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiApiKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiApiKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiApiKey',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiBaseUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiBaseUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBaseUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiBaseUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiBaseUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiBaseUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiBaseUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiBaseUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBaseUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiBaseUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiBaseUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiBaseUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiBaseUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiBaseUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiBaseUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiBaseUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBaseUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiBaseUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBaseUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiBaseUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiBuiltinModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiBuiltinModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiBuiltinModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiBuiltinModelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiBuiltinModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiBuiltinModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiBuiltinModelId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiBuiltinModelId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiBuiltinModelId',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiBuiltinModelIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiBuiltinModelId',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiLicenseCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiLicenseCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiLicenseCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiLicenseCode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiLicenseCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiLicenseCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiLicenseCode',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiLicenseCode',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiLicenseCode',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiLicenseCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiLicenseCode',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiModel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiModel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> aiModelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiModel',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiModel',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'aiModelCacheAt',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'aiModelCacheAt',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiModelCacheAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiModelCacheAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiModelCacheAt',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiModelCacheAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiModelCacheJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiModelCacheJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiModelCacheJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiModelCacheJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiModelCacheJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiModelCacheJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiModelCacheJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiModelCacheJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiModelCacheJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiModelCacheJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiModelCacheJson',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiProviderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiProviderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiProviderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiProviderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiProviderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiProviderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiProviderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiProviderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiProviderId',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiProviderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiProviderId',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiSystemPrompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiSystemPrompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiSystemPrompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiSystemPrompt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'aiSystemPrompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'aiSystemPrompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'aiSystemPrompt',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'aiSystemPrompt',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiSystemPrompt',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiSystemPromptIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'aiSystemPrompt',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiThinkingLevelEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiThinkingLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiThinkingLevelGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'aiThinkingLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiThinkingLevelLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'aiThinkingLevel',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiThinkingLevelBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'aiThinkingLevel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      aiVisionEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'aiVisionEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      chatSessionIdEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chatSessionId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      chatSessionIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chatSessionId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      chatSessionIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chatSessionId',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      chatSessionIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chatSessionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      contextWindowTokensEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'contextWindowTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      contextWindowTokensGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'contextWindowTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      contextWindowTokensLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'contextWindowTokens',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      contextWindowTokensBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'contextWindowTokens',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      defaultUnitPriceEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'defaultUnitPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      defaultUnitPriceGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'defaultUnitPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      defaultUnitPriceLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'defaultUnitPrice',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      defaultUnitPriceBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'defaultUnitPrice',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      lastBackupMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastBackupMs',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      lastBackupMsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastBackupMs',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      lastBackupMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastBackupMs',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      lastBackupMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastBackupMs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportFontScaleEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportFontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportFontScaleGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reportFontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportFontScaleLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reportFontScale',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportFontScaleBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reportFontScale',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportGroupByEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportGroupBy',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportGroupByGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reportGroupBy',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportGroupByLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reportGroupBy',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportGroupByBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reportGroupBy',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportShowPhotoEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportShowPhoto',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportSubtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reportSubtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reportSubtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reportSubtitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reportSubtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reportSubtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reportSubtitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reportSubtitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportSubtitle',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportSubtitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reportSubtitle',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTemplateEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportTemplate',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTemplateGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reportTemplate',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTemplateLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reportTemplate',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTemplateBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reportTemplate',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'reportTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'reportTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'reportTitle',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'reportTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'reportTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'reportTitle',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'reportTitle',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'reportTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      reportTitleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'reportTitle',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      themeModeIndexEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'themeModeIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      themeModeIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'themeModeIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      themeModeIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'themeModeIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      themeModeIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'themeModeIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavDirEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavDirGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'webdavDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavDirLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'webdavDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavDirBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'webdavDir',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavDirStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'webdavDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavDirEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'webdavDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavDirContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'webdavDir',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavDirMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'webdavDir',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavDirIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavDir',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavDirIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'webdavDir',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavEnabledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavEnabled',
        value: value,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavPassEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavPass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'webdavPass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'webdavPass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavPassBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'webdavPass',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'webdavPass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'webdavPass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'webdavPass',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavPassMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'webdavPass',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavPass',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavPassIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'webdavPass',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUrlEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUrlGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'webdavUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUrlLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'webdavUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUrlBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'webdavUrl',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUrlStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'webdavUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUrlEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'webdavUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUrlContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'webdavUrl',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUrlMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'webdavUrl',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUrlIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUrlIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'webdavUrl',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUserEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavUser',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'webdavUser',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'webdavUser',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUserBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'webdavUser',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'webdavUser',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'webdavUser',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'webdavUser',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition> webdavUserMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'webdavUser',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'webdavUser',
        value: '',
      ));
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterFilterCondition>
      webdavUserIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'webdavUser',
        value: '',
      ));
    });
  }
}

extension AppSettingQueryObject
    on QueryBuilder<AppSetting, AppSetting, QFilterCondition> {}

extension AppSettingQueryLinks
    on QueryBuilder<AppSetting, AppSetting, QFilterCondition> {}

extension AppSettingQuerySortBy
    on QueryBuilder<AppSetting, AppSetting, QSortBy> {
  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByActiveProfileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeProfileId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByActiveProfileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeProfileId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiApiKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiApiKey', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiApiKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiApiKey', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiBaseUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBaseUrl', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiBaseUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBaseUrl', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiBuiltinModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBuiltinModelId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByAiBuiltinModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBuiltinModelId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiLicenseCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiLicenseCode', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiLicenseCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiLicenseCode', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModel', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModel', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiModelCacheAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheAt', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByAiModelCacheAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheAt', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiModelCacheJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheJson', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByAiModelCacheJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheJson', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiProviderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiProviderId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiProviderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiProviderId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiSystemPrompt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiSystemPrompt', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByAiSystemPromptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiSystemPrompt', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiThinkingLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiThinkingLevel', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByAiThinkingLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiThinkingLevel', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByAiVisionEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiVisionEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByAiVisionEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiVisionEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByChatSessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatSessionId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByChatSessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatSessionId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByContextWindowTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextWindowTokens', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByContextWindowTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextWindowTokens', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByDefaultUnitPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultUnitPrice', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByDefaultUnitPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultUnitPrice', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByLastBackupMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupMs', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByLastBackupMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupMs', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportFontScale', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByReportFontScaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportFontScale', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportGroupBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportGroupBy', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportGroupByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportGroupBy', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportShowPhoto() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportShowPhoto', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByReportShowPhotoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportShowPhoto', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportSubtitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportSubtitle', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByReportSubtitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportSubtitle', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTemplate', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByReportTemplateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTemplate', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTitle', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByReportTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTitle', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByThemeModeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeModeIndex', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      sortByThemeModeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeModeIndex', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavDir() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavDir', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavDirDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavDir', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavPass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavPass', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavPassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavPass', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUrl', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUrl', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavUser() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUser', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> sortByWebdavUserDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUser', Sort.desc);
    });
  }
}

extension AppSettingQuerySortThenBy
    on QueryBuilder<AppSetting, AppSetting, QSortThenBy> {
  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByActiveProfileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeProfileId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByActiveProfileIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'activeProfileId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiApiKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiApiKey', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiApiKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiApiKey', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiBaseUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBaseUrl', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiBaseUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBaseUrl', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiBuiltinModelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBuiltinModelId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByAiBuiltinModelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiBuiltinModelId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiLicenseCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiLicenseCode', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiLicenseCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiLicenseCode', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModel', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModel', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiModelCacheAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheAt', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByAiModelCacheAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheAt', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiModelCacheJson() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheJson', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByAiModelCacheJsonDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiModelCacheJson', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiProviderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiProviderId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiProviderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiProviderId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiSystemPrompt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiSystemPrompt', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByAiSystemPromptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiSystemPrompt', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiThinkingLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiThinkingLevel', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByAiThinkingLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiThinkingLevel', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByAiVisionEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiVisionEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByAiVisionEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'aiVisionEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByChatSessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatSessionId', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByChatSessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chatSessionId', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByContextWindowTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextWindowTokens', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByContextWindowTokensDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'contextWindowTokens', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByDefaultUnitPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultUnitPrice', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByDefaultUnitPriceDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'defaultUnitPrice', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByLastBackupMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupMs', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByLastBackupMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastBackupMs', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportFontScale', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByReportFontScaleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportFontScale', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportGroupBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportGroupBy', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportGroupByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportGroupBy', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportShowPhoto() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportShowPhoto', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByReportShowPhotoDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportShowPhoto', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportSubtitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportSubtitle', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByReportSubtitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportSubtitle', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTemplate', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByReportTemplateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTemplate', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTitle', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByReportTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'reportTitle', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByThemeModeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeModeIndex', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy>
      thenByThemeModeIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'themeModeIndex', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavDir() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavDir', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavDirDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavDir', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavEnabled', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavEnabledDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavEnabled', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavPass() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavPass', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavPassDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavPass', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavUrl() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUrl', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavUrlDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUrl', Sort.desc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavUser() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUser', Sort.asc);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QAfterSortBy> thenByWebdavUserDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'webdavUser', Sort.desc);
    });
  }
}

extension AppSettingQueryWhereDistinct
    on QueryBuilder<AppSetting, AppSetting, QDistinct> {
  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByActiveProfileId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'activeProfileId');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiApiKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiApiKey', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiBaseUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiBaseUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiBuiltinModelId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiBuiltinModelId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiLicenseCode(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiLicenseCode',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiModel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiModel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiModelCacheAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiModelCacheAt');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiModelCacheJson(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiModelCacheJson',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiProviderId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiProviderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiSystemPrompt(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiSystemPrompt',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiThinkingLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiThinkingLevel');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByAiVisionEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'aiVisionEnabled');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByChatSessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chatSessionId');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct>
      distinctByContextWindowTokens() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'contextWindowTokens');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByDefaultUnitPrice() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'defaultUnitPrice');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByLastBackupMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastBackupMs');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByReportFontScale() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportFontScale');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByReportGroupBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportGroupBy');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByReportShowPhoto() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportShowPhoto');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByReportSubtitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportSubtitle',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByReportTemplate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportTemplate');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByReportTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'reportTitle', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByThemeModeIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'themeModeIndex');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByWebdavDir(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'webdavDir', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByWebdavEnabled() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'webdavEnabled');
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByWebdavPass(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'webdavPass', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByWebdavUrl(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'webdavUrl', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<AppSetting, AppSetting, QDistinct> distinctByWebdavUser(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'webdavUser', caseSensitive: caseSensitive);
    });
  }
}

extension AppSettingQueryProperty
    on QueryBuilder<AppSetting, AppSetting, QQueryProperty> {
  QueryBuilder<AppSetting, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> activeProfileIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'activeProfileId');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> aiApiKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiApiKey');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> aiBaseUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiBaseUrl');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations>
      aiBuiltinModelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiBuiltinModelId');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> aiLicenseCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiLicenseCode');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> aiModelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiModel');
    });
  }

  QueryBuilder<AppSetting, DateTime?, QQueryOperations>
      aiModelCacheAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiModelCacheAt');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations>
      aiModelCacheJsonProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiModelCacheJson');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> aiProviderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiProviderId');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> aiSystemPromptProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiSystemPrompt');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> aiThinkingLevelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiThinkingLevel');
    });
  }

  QueryBuilder<AppSetting, bool, QQueryOperations> aiVisionEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'aiVisionEnabled');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> chatSessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chatSessionId');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations>
      contextWindowTokensProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'contextWindowTokens');
    });
  }

  QueryBuilder<AppSetting, double, QQueryOperations>
      defaultUnitPriceProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'defaultUnitPrice');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> lastBackupMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastBackupMs');
    });
  }

  QueryBuilder<AppSetting, double, QQueryOperations> reportFontScaleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportFontScale');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> reportGroupByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportGroupBy');
    });
  }

  QueryBuilder<AppSetting, bool, QQueryOperations> reportShowPhotoProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportShowPhoto');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> reportSubtitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportSubtitle');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> reportTemplateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportTemplate');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> reportTitleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'reportTitle');
    });
  }

  QueryBuilder<AppSetting, int, QQueryOperations> themeModeIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'themeModeIndex');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> webdavDirProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'webdavDir');
    });
  }

  QueryBuilder<AppSetting, bool, QQueryOperations> webdavEnabledProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'webdavEnabled');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> webdavPassProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'webdavPass');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> webdavUrlProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'webdavUrl');
    });
  }

  QueryBuilder<AppSetting, String, QQueryOperations> webdavUserProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'webdavUser');
    });
  }
}
