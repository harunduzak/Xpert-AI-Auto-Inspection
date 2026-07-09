import tensorflow as tf

# Kendi dosya adına göre düzenle
interpreter = tf.lite.Interpreter(model_path="damage_best_float32.tflite")
interpreter.allocate_tensors()

print("--- Giriş (Input) Detayları ---")
print(interpreter.get_input_details())

print("\n--- Çıkış (Output) Detayları ---")
print(interpreter.get_output_details())