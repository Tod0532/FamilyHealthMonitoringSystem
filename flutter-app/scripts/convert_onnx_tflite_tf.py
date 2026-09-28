"""使用 TensorFlow 直接转换 ONNX -> TFLite
方案: ONNX -> SavedModel (tf2onnx) -> TFLite
"""
import os
import sys

ONNX_PATH = 'assets/models/lcd_detector.onnx'
TFLITE_PATH = 'assets/models/lcd_detector.tflite'

def convert_via_tf2onnx():
    """使用 tf2onnx 转换 ONNX 到 TensorFlow 再到 TFLite"""
    try:
        import tf2onnx
        import tensorflow as tf
        import onnx
    except ImportError as e:
        print(f'缺少依赖: {e}')
        print('运行: pip install tf2onnx')
        return False

    print('步骤1: 加载 ONNX 模型...')
    onnx_model = onnx.load(ONNX_PATH)
    print(f'  输入: {onnx_model.graph.input}')
    print(f'  输出: {onnx_model.graph.output}')

    print('\n步骤2: 转换为 TensorFlow SavedModel...')
    saved_model_dir = 'assets/models/lcd_temp_savedmodel'

    # 获取输入形状
    input_tensor = onnx_model.graph.input[0]
    input_shape = [d.dim_value for d in input_tensor.type.tensor_type.shape.dim]
    print(f'  输入形状: {input_shape}')

    # 转换为 SavedModel
    model_proto, _ = tf2onnx.convert.from_onnx(
        onnx_model,
        input_signature=[tf.TensorSpec(input_shape, tf.float32, name=input_tensor.name)]
    )

    print('\n步骤3: 保存为 SavedModel...')
    # tf2onnx 直接输出 TensorFlow graph
    with tf.Graph().as_default() as tf_graph:
        tf.import_graph_def(model_proto, name='')

        # 获取输入输出张量
        input_name = tf_graph.get_tensor_by_name(f'{input_tensor.name}:0')

        # 找到输出节点
        output_names = []
        for out in onnx_model.graph.output:
            output_names.append(f'{out.name}:0')
        print(f'  输出: {output_names}')

        # 创建 SavedModel
        with tf.Session(graph=tf_graph) as sess:
            tf.saved_model.simple_save(
                sess,
                saved_model_dir,
                inputs={'input': input_name},
                outputs={out.name: tf_graph.get_tensor_by_name(out.name) for out in output_names}
            )

    print('\n步骤4: 转换为 TFLite...')
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()
    with open(TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)

    print(f'  模型大小: {len(tflite_model) / 1024 / 1024:.2f} MB')
    print(f'  保存路径: {TFLITE_PATH}')
    return True

if __name__ == '__main__':
    print('=' * 50)
    print('ONNX -> TFLite 转换 (tf2onnx 方案)')
    print('=' * 50)
    success = convert_via_tf2onnx()
    if success:
        print('\n转换成功!')
    else:
        print('\n转换失败')
