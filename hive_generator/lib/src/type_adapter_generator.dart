import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:hive_generator/src/builder.dart';
import 'package:hive_generator/src/class_builder.dart';
import 'package:hive_generator/src/enum_builder.dart';
import 'package:hive_generator/src/helper.dart';
import 'package:source_gen/source_gen.dart';
import 'package:hive/hive.dart';

class TypeAdapterGenerator extends GeneratorForAnnotation<HiveType> {
  @override
  Future<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    var cls = getClass(element);
    var library = await buildStep.inputLibrary;
    var gettersAndSetters = getAccessors(cls, library);

    var getters = gettersAndSetters[0];
    verifyFieldIndices(getters);

    var setters = gettersAndSetters[0];
    verifyFieldIndices(setters);

    var typeId = getTypeId(annotation);

    var adapterName = getAdapterName(cls.name, annotation);
    var builder = cls.isEnum
        ? EnumBuilder(cls, getters)
        : ClassBuilder(cls, getters, setters);

    return '''
    class $adapterName extends TypeAdapter<${cls.name}> {
      @override
      final int typeId = $typeId;

      @override
      ${cls.name} read(BinaryReader reader) {
        ${builder.buildRead()}
      }

      @override
      void write(BinaryWriter writer, ${cls.name} obj) {
        ${builder.buildWrite()}
      }

      @override
      int get hashCode => typeId.hashCode;

      @override
      bool operator ==(Object other) =>
          identical(this, other) ||
          other is $adapterName &&
              runtimeType == other.runtimeType &&
              typeId == other.typeId;
    }
    ''';
  }

  ClassElement getClass(Element element) {
    check(element.kind == ElementKind.CLASS || element.kind == ElementKind.ENUM,
        'Only classes or enums are allowed to be annotated with @HiveType.');

    return element as ClassElement;
  }

  Set<String> getAllAccessorNames(ClassElement cls) {
    var accessorNames = <String>{};

    var supertypes = cls.allSupertypes.map((it) => it.element);
    for (var type in [cls, ...supertypes]) {
      for (var accessor in type.accessors) {
        // TODO not ideal
        if (accessor.name == 'runtimeType' ||
            accessor.name == 'hashCode' ||
            accessor.name == 'copyWith' ||
            (cls.isEnum &&
                (accessor.name == 'index' || accessor.name == 'values'))) {
          continue;
        }
        if (accessor.isSetter) {
          var name = accessor.name;
          accessorNames.add(name.substring(0, name.length - 1));
        } else {
          accessorNames.add(accessor.name);
        }
      }
    }

    return accessorNames;
  }

  List<List<AdapterField>> getAccessors(
      ClassElement cls, LibraryElement library) {
    var accessorNames = getAllAccessorNames(cls);

    var getters = <AdapterField>[];
    var setters = <AdapterField>[];
    var fieldNum = 0;
    for (var name in accessorNames) {
      final getter = cls.lookUpGetter(name, library);
      final setter = cls.lookUpSetter('$name=', library);

      if (getter != null) {
        final field = getter.variable;
        getters.add(AdapterField(fieldNum, field.name, field.type));
      }

      if (setter != null) {
        final field = setter.variable;
        setters.add(AdapterField(fieldNum, field.name, field.type));
      }
      if (setter != null || getter != null) {
        fieldNum++;
      }
    }

    return [getters, setters];
  }

  void verifyFieldIndices(List<AdapterField> fields) {
    for (var field in fields) {
      check(field.index >= 0 || field.index <= 255,
          'Field numbers can only be in the range 0-255.');

      for (var otherField in fields) {
        if (otherField == field) continue;
        if (otherField.index == field.index) {
          throw HiveError(
            'Duplicate field number: ${field.index}. Fields "${field.name}" '
            'and "${otherField.name}" have the same number.',
          );
        }
      }
    }
  }

  String getAdapterName(String typeName, ConstantReader annotation) {
    var annAdapterName = annotation.read('adapterName');
    if (annAdapterName.isNull) {
      return '${typeName}Adapter';
    } else {
      return annAdapterName.stringValue;
    }
  }

  int getTypeId(ConstantReader annotation) {
    check(
      !annotation.read('typeId').isNull,
      'You have to provide a non-null typeId.',
    );
    return annotation.read('typeId').intValue;
  }
}
