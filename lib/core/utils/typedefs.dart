/// Typedefs comunes para funciones de la aplicación

/// Función que retorna un Future de tipo T
typedef FutureFunction<T> = Future<T> Function();

/// Función que retorna un Future de tipo T con parámetro P
typedef FutureFunctionWithParam<T, P> = Future<T> Function(P param);

/// Función que retorna un Future de tipo T con múltiples parámetros
typedef FutureFunctionWithParams<T> = Future<T> Function(List<dynamic> params);

/// Función que retorna un Stream de tipo T
typedef StreamFunction<T> = Stream<T> Function();

/// Función que retorna un Stream de tipo T con parámetro P
typedef StreamFunctionWithParam<T, P> = Stream<T> Function(P param);

/// Función de callback sin parámetros
typedef VoidCallback = void Function();

/// Función de callback con parámetro
typedef Callback<T> = void Function(T param);

/// Función de callback con múltiples parámetros
typedef MultiCallback<T, P> = void Function(T param1, P param2);
