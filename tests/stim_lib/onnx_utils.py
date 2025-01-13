# Open onnx from model zoo
# https://netron.app/?url=https://github.com/onnx/models/blob/main/validated/vision/classification/mobilenet/model/mobilenetv2-12-int8.onnx

import onnx
from onnx import numpy_helper as nphelp 

def get_initializer_by_name(onnx_model,name):
    for init in onnx_model.graph.initializer:
        if init.name == name:
            return init
    raise LookupError(f'Could not find initializer with name {name}')

def load_weights_text(initializer_name):
    return    

def get_quantized_mbv2(path):
    '''
    Download mbv2 int8 onnx model via wget into path
    '''

    return 


model = onnx.load('mobilenetv2-12-int8.onnx')
node = model.graph.node[1].input[0]
test_weights = nphelp.to_array(get_initializer_by_name(model,"475_quantized"))