import numpy as np
from scipy.signal import convolve2d
import os

def generate_tb_cluster_stimulus(
    actBits = 3,
    weightBits = 3,
    nActs = 16,
    nWeights = 3,
    seed = 0,
    path = 'tb_cluster',
):

    # Check if path exists
    if not os.path.exists(path):
        raise ValueError(f'Path {path} does not exist.')

    nOuts = nActs - nWeights + 1

    np.random.seed(0)
    a = np.random.randint(-2**(actBits-1),2**(actBits-1)-1,size=(nActs,nActs))
    w = np.random.randint(-2**(weightBits-1),2**(weightBits-1)-1,size=(nWeights,nWeights))
    o = convolve2d(a,w[::-1].T[::-1].T,mode='valid')

    print(f'PE cluster must be {nOuts} PEs wide and {nWeights} PEs high ')

    ids_acts = np.zeros((nOuts+1,nWeights))
    for x,idx in enumerate(ids_acts):
        for y,id in enumerate(idx):
            ids_acts[x][y] = x + y
    ids_acts[-1] = [0,0,0] # Only zeros for the Y-bus for now (you only need it for multichannel convolutions)
    
    ids_weights = np.zeros((nOuts+1,nWeights))
    for x,idx in enumerate(ids_weights):
        ids_weights[x] = [i for i in range(nWeights)]
    ids_weights[-1] = [0,0,0] # Only zeros for the Y-bus for now (you only need it for multichannel convolutions)

    tag_order_acts = []
    for i in range(nActs):
        tag_order_acts.append([0,i])
    tag_order_acts = np.array(tag_order_acts)

    tag_order_weights = []
    for i in range(nWeights):
        tag_order_weights.append([0,i])
    tag_order_weights = np.array(tag_order_weights)

    np.savetxt(path + '/a.txt',a,'%i')
    np.savetxt(path + '/w.txt',w,'%i')
    np.savetxt(path + '/o.txt',o,'%i')
    np.savetxt(path + '/ids_acts.txt',ids_acts,'%i')
    np.savetxt(path + '/ids_weights.txt',ids_weights,'%i')
    np.savetxt(path + '/tag_order_acts.txt',tag_order_acts,'%i')
    np.savetxt(path + '/tag_order_weights.txt',tag_order_weights,'%i')


def generate_tb_pe_stimulus(
    actBits = 8,
    weightBits = 8,
    seed = 0,
    path = 'tb_PE',
):

    # Check if path exists
    if not os.path.exists(path):
        raise ValueError(f'Path {path} does not exist.')

    np.random.seed(0)    
    a = np.random.randint(-2**(actBits-1),2**(actBits-1)-1,size=16)
    w = np.random.randint(-2**(weightBits-1),2**(weightBits-1)-1,size=3)
    o = np.convolve(a,w[::-1],'valid')

    np.savetxt(path + '/a.txt',a,'%i')
    np.savetxt(path + '/w.txt',w,'%i')
    np.savetxt(path + '/o.txt',o+1,'%i')