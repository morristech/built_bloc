import 'package:analyzer/dart/element/element.dart';
import 'package:built_bloc/built_bloc.dart';
import 'package:built_bloc_generator/src/annotations.dart';
import 'package:built_bloc_generator/src/helpers.dart';
import 'package:code_builder/code_builder.dart';
import 'stream.dart';
import 'sink.dart';
import 'listen.dart';

class BlocGenerator {
  final ClassElement element;
  final List<StreamGenerator> streams;
  final List<SinkGenerator> sinks;
  final List<ListenGenerator> listens;

  BlocGenerator(this.element)
      : this.listens = _scanForListens(element),
        this.streams = _scanForStreams(element),
        this.sinks = _scanForSinks(element);

  String get name => privateName(this.element.name, "Bloc");

  Class buildMixin() {
    final builder = ClassBuilder()
      ..name = this.name
      ..implements.add(refer("GeneratedBloc<${element.name}>"));

    builder.fields.add(Field((b) => b
      ..name = "_parent"
      ..type = refer(element.name)));

    this.streams.forEach((s) => s.buildGetter(builder));
    this.sinks.forEach((s) => s.buildGetter(builder));

    this.buildSubscription(builder);

    return builder.build();
  }

  void buildSubscription(ClassBuilder builder) {
    final block = BlockBuilder();
    block.statements.add(Code("this._parent = value;"));
    this.streams.forEach((s) => s.buildSubscription(block));
    this.sinks.forEach((s) => s.buildSubscription(block));
    this.listens.forEach((s) => s.buildSubscription(block));

    builder.methods.add(Method((b) => b
      ..name = "subscribeParent"
      ..annotations.add(CodeExpression(Code("override")))
      ..returns = refer("void")
      ..body = block.build()
      ..requiredParameters.add(Parameter((b) => b
        ..name = "value"
        ..type = refer(this.element.name)))));
  }

  static List<StreamGenerator> _scanForStreams(ClassElement element) {
    return element.fields
        .map((field) => ifAnnotated<BlocStream, StreamGenerator>(field,
            (e, a) => StreamGenerator(field: e as FieldElement, annotation: streamFromAnnotation(a))))
        .where((x) => x != null)
        .toList();
  }

  static List<SinkGenerator> _scanForSinks(ClassElement element) {
    return element.fields
        .map((field) => ifAnnotated<BlocSink, SinkGenerator>(field, 
            (e, a) => SinkGenerator(field: e as FieldElement, annotation: sinkFromAnnotation(a))))
        .where((x) => x != null)
        .toList();
  }

  static List<ListenGenerator> _scanForListens(ClassElement element) {
    return element.methods
        .map((method) => ifAnnotated<Listen, ListenGenerator>(
            method, 
            (e, a) =>
                ListenGenerator(method: e as MethodElement, annotation: listenFromAnnotation(a))))
        .where((x) => x != null)
        .toList();
  }
}