// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unit_rule.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetUnitRuleCollection on Isar {
  IsarCollection<UnitRule> get unitRules => this.collection();
}

const UnitRuleSchema = CollectionSchema(
  name: r'UnitRule',
  id: 537505861062902000,
  properties: {
    r'createdAt': PropertySchema(
      id: 0,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'denominator': PropertySchema(
      id: 1,
      name: r'denominator',
      type: IsarType.long,
    ),
    r'factor': PropertySchema(
      id: 2,
      name: r'factor',
      type: IsarType.double,
    ),
    r'fromUnit': PropertySchema(
      id: 3,
      name: r'fromUnit',
      type: IsarType.string,
    ),
    r'label': PropertySchema(
      id: 4,
      name: r'label',
      type: IsarType.string,
    ),
    r'numerator': PropertySchema(
      id: 5,
      name: r'numerator',
      type: IsarType.long,
    ),
    r'styleModel': PropertySchema(
      id: 6,
      name: r'styleModel',
      type: IsarType.string,
    ),
    r'toUnit': PropertySchema(
      id: 7,
      name: r'toUnit',
      type: IsarType.string,
    )
  },
  estimateSize: _unitRuleEstimateSize,
  serialize: _unitRuleSerialize,
  deserialize: _unitRuleDeserialize,
  deserializeProp: _unitRuleDeserializeProp,
  idName: r'id',
  indexes: {
    r'fromUnit': IndexSchema(
      id: -6668202851689766421,
      name: r'fromUnit',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'fromUnit',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'styleModel': IndexSchema(
      id: 7155934246782563793,
      name: r'styleModel',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'styleModel',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _unitRuleGetId,
  getLinks: _unitRuleGetLinks,
  attach: _unitRuleAttach,
  version: '3.4.1',
);

int _unitRuleEstimateSize(
  UnitRule object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.fromUnit.length * 3;
  bytesCount += 3 + object.label.length * 3;
  bytesCount += 3 + object.styleModel.length * 3;
  bytesCount += 3 + object.toUnit.length * 3;
  return bytesCount;
}

void _unitRuleSerialize(
  UnitRule object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.createdAt);
  writer.writeLong(offsets[1], object.denominator);
  writer.writeDouble(offsets[2], object.factor);
  writer.writeString(offsets[3], object.fromUnit);
  writer.writeString(offsets[4], object.label);
  writer.writeLong(offsets[5], object.numerator);
  writer.writeString(offsets[6], object.styleModel);
  writer.writeString(offsets[7], object.toUnit);
}

UnitRule _unitRuleDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = UnitRule();
  object.createdAt = reader.readDateTime(offsets[0]);
  object.denominator = reader.readLong(offsets[1]);
  object.fromUnit = reader.readString(offsets[3]);
  object.id = id;
  object.numerator = reader.readLong(offsets[5]);
  object.styleModel = reader.readString(offsets[6]);
  object.toUnit = reader.readString(offsets[7]);
  return object;
}

P _unitRuleDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readDouble(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readString(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _unitRuleGetId(UnitRule object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _unitRuleGetLinks(UnitRule object) {
  return [];
}

void _unitRuleAttach(IsarCollection<dynamic> col, Id id, UnitRule object) {
  object.id = id;
}

extension UnitRuleQueryWhereSort on QueryBuilder<UnitRule, UnitRule, QWhere> {
  QueryBuilder<UnitRule, UnitRule, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension UnitRuleQueryWhere on QueryBuilder<UnitRule, UnitRule, QWhereClause> {
  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> idBetween(
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

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> fromUnitEqualTo(
      String fromUnit) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'fromUnit',
        value: [fromUnit],
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> fromUnitNotEqualTo(
      String fromUnit) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromUnit',
              lower: [],
              upper: [fromUnit],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromUnit',
              lower: [fromUnit],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromUnit',
              lower: [fromUnit],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'fromUnit',
              lower: [],
              upper: [fromUnit],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> styleModelEqualTo(
      String styleModel) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'styleModel',
        value: [styleModel],
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterWhereClause> styleModelNotEqualTo(
      String styleModel) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'styleModel',
              lower: [],
              upper: [styleModel],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'styleModel',
              lower: [styleModel],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'styleModel',
              lower: [styleModel],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'styleModel',
              lower: [],
              upper: [styleModel],
              includeUpper: false,
            ));
      }
    });
  }
}

extension UnitRuleQueryFilter
    on QueryBuilder<UnitRule, UnitRule, QFilterCondition> {
  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> denominatorEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'denominator',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition>
      denominatorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'denominator',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> denominatorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'denominator',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> denominatorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'denominator',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> factorEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'factor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> factorGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'factor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> factorLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'factor',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> factorBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'factor',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fromUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fromUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fromUnit',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'fromUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'fromUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'fromUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'fromUnit',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fromUnit',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> fromUnitIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'fromUnit',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> idBetween(
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

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'label',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'label',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'label',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'label',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> labelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'label',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> numeratorEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'numerator',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> numeratorGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'numerator',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> numeratorLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'numerator',
        value: value,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> numeratorBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'numerator',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'styleModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'styleModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'styleModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'styleModel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'styleModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'styleModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'styleModel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'styleModel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> styleModelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'styleModel',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition>
      styleModelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'styleModel',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'toUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'toUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'toUnit',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'toUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'toUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'toUnit',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'toUnit',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'toUnit',
        value: '',
      ));
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterFilterCondition> toUnitIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'toUnit',
        value: '',
      ));
    });
  }
}

extension UnitRuleQueryObject
    on QueryBuilder<UnitRule, UnitRule, QFilterCondition> {}

extension UnitRuleQueryLinks
    on QueryBuilder<UnitRule, UnitRule, QFilterCondition> {}

extension UnitRuleQuerySortBy on QueryBuilder<UnitRule, UnitRule, QSortBy> {
  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByDenominator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'denominator', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByDenominatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'denominator', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByFactor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'factor', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByFactorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'factor', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByFromUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUnit', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByFromUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUnit', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByNumerator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numerator', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByNumeratorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numerator', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByStyleModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'styleModel', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByStyleModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'styleModel', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByToUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUnit', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> sortByToUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUnit', Sort.desc);
    });
  }
}

extension UnitRuleQuerySortThenBy
    on QueryBuilder<UnitRule, UnitRule, QSortThenBy> {
  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByDenominator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'denominator', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByDenominatorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'denominator', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByFactor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'factor', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByFactorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'factor', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByFromUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUnit', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByFromUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fromUnit', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByLabel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByLabelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'label', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByNumerator() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numerator', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByNumeratorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'numerator', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByStyleModel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'styleModel', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByStyleModelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'styleModel', Sort.desc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByToUnit() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUnit', Sort.asc);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QAfterSortBy> thenByToUnitDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'toUnit', Sort.desc);
    });
  }
}

extension UnitRuleQueryWhereDistinct
    on QueryBuilder<UnitRule, UnitRule, QDistinct> {
  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByDenominator() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'denominator');
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByFactor() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'factor');
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByFromUnit(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fromUnit', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByLabel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'label', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByNumerator() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'numerator');
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByStyleModel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'styleModel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<UnitRule, UnitRule, QDistinct> distinctByToUnit(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'toUnit', caseSensitive: caseSensitive);
    });
  }
}

extension UnitRuleQueryProperty
    on QueryBuilder<UnitRule, UnitRule, QQueryProperty> {
  QueryBuilder<UnitRule, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<UnitRule, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<UnitRule, int, QQueryOperations> denominatorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'denominator');
    });
  }

  QueryBuilder<UnitRule, double, QQueryOperations> factorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'factor');
    });
  }

  QueryBuilder<UnitRule, String, QQueryOperations> fromUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fromUnit');
    });
  }

  QueryBuilder<UnitRule, String, QQueryOperations> labelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'label');
    });
  }

  QueryBuilder<UnitRule, int, QQueryOperations> numeratorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'numerator');
    });
  }

  QueryBuilder<UnitRule, String, QQueryOperations> styleModelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'styleModel');
    });
  }

  QueryBuilder<UnitRule, String, QQueryOperations> toUnitProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'toUnit');
    });
  }
}
