import numpy as np
from scipy.signal import convolve2d

class quantized_tensor:
    '''
    Quantized Tensor
    Reals are normalized to [-1,1]
    If mode is 'symmetric', zero point is 0 and scale is 2 / (2**precision - 1)
    
    Main attributes:
    real_values : np.ndarray -- Real values of the tensor
    quantized_values : np.ndarray -- Quantized values of the tensor
    scale : float -- Scale of the quantization
    zero_point : float -- Zero point of the quantization
    shape : tuple -- Shape of the tensor
    fake_quantized_values : np.ndarray -- Quantized values translated back to real range
    '''

    def __init__(self,shape,precision,mode='symmetric',real_values=None,quantized_values=None,scale=None,zero_point=None):
        if real_values is not None:
            self.real_values = real_values
            self.quantize(precision,mode)
            self.dequantize()
        elif quantized_values is not None:
            self.real_values = None
            self.quantized_values = quantized_values
            self.scale = scale
            self.zero_point = zero_point
            self.dequantize()
        else:
            self.real_values = np.random.uniform(-1,1,shape)
            self.quantize(precision,mode)
            self.dequantize()
        self.shape = self.real_values.shape
        return

    def quantize(self, precision, mode='symmetric'):
        if mode == 'maxmin' : 
            clip_high = self.real_values.max()
            clip_low = self.real_values.min()
            self.scale = (clip_high - clip_low) / (2**precision - 1)
            self.zero_point = clip_low
        elif mode == '3sigma' :
            mean = self.real_values.mean()
            std = self.real_values.std()
            self.scale = std*3 / (2**precision - 1)
            self.zero_point = mean
        elif mode == 'symmetric':
            self.scale = 2 / (2**precision - 1)
            self.zero_point = 0

        # r = S(q - Z)
        self.quantized_values = np.round( (self.real_values / self.scale) + self.zero_point ).astype(int)

    def dequantize(self):
        " Creates fake quantization values from the quantized values, like EdMIPS "
        self.fake_quantized_values = (self.quantized_values - self.zero_point) * self.scale
        if self.real_values is None:
            self.real_values = self.fake_quantized_values
        return

def convolve_fake_quantized(a,w) -> np.ndarray:
    " o = aw "
    return convolve2d(a.fake_quantized_values,w.fake_quantized_values[::-1].T[::-1].T,mode='valid')

def convolve_reals(a,w) -> np.ndarray:
    " o = aw "
    return convolve2d(a.real_values,w.real_values[::-1].T[::-1].T,mode='valid')

def scaling_quantized_convolution(a,w,outBits,internalPrecision) -> quantized_tensor:
    " o = aw but quantized "

    # Convolution
    qaqw = convolve2d(a.quantized_values,w.quantized_values[::-1].T[::-1].T,mode='valid')

    # Scaling
    out_scale = 2 / (2**outBits - 1)
    newscale = a.scale * w.scale / out_scale
    m0, shift = convert_scale_to_shift_and_m0(
                    newscale,
                    precision=internalPrecision
                )

    fp_m = m0 * 2**(shift)

    # Reals accounting for quantized and fixed point error
    o_q = qaqw * fp_m

    # Quantized tensor of the output
    o_qtensor = quantized_tensor(
                    qaqw.shape,
                    outBits,
                    quantized_values=o_q,
                    scale=out_scale,
                    zero_point=0 # Assume 0 for now, might be bad later.
                )

    return o_qtensor
    
def convert_scale_to_shift_and_m0(scale,precision=16):
    " Convert scale to shift and zero point "
    shift = int(np.ceil(np.log2(scale)))
    m0 = scale / 2**shift
    fp_string = convert_to_fixed_point(m0,precision)
    m0_clipped = fixed_point_to_float(fp_string,precision)
    return m0_clipped, shift

def convert_to_fixed_point(number,precision):
    " Convert a float [0,1] to fixed point binary "
    out = ''
    for i in range(precision):
        number *= 2
        integer = int(number)
        number -= integer
        out += str(integer)
    return out

def fixed_point_to_float(number,precision):
    " Convert a fixed point binary to float [0,1] "
    out = 0
    for i in range(precision):
        out += int(number[i]) * 2**-(i+1)
    return out

def saturating_clip (
    num_i, outBits = 8
):

    min = -(2**(outBits-1))
    max = 2**(outBits-1)-1
    
    if(num_i < min):
        return min
    if(num_i > max):
        return max
    
    return num_i