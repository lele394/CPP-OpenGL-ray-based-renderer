import numpy as np
import os

def convert_and_save_chunks(array, chunk_size, output_dir="."):
    """
    Splits a numpy uint32 array into chunks of size (chunk_size, chunk_size, chunk_size),
    pads with zeros as needed, and saves each chunk to 'chunk-x-y-z.bin' using tofile().
    
    Parameters:
        array (np.ndarray): Input numpy array of dtype np.uint32 and shape at least 3D.
        chunk_size (int): The size of each chunk along each axis.
        output_dir (str): Directory to save the chunk files.
    """
    if not isinstance(array, np.ndarray):
        raise ValueError("Input must be a numpy array.")
    if array.dtype != np.uint32:
        raise ValueError("Array must be of dtype np.uint32.")
    if array.ndim < 3:
        raise ValueError("Array must be at least 3-dimensional.")
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Get shape and pad to nearest multiple of chunk_size
    original_shape = array.shape
    pad_z = (chunk_size - original_shape[0] % chunk_size) % chunk_size
    pad_y = (chunk_size - original_shape[1] % chunk_size) % chunk_size
    pad_x = (chunk_size - original_shape[2] % chunk_size) % chunk_size
    
    pad_width = ((0, pad_z), (0, pad_y), (0, pad_x))
    if array.ndim > 3:
        pad_width += ((0,0),)*(array.ndim-3)
    
    padded_array = np.pad(array, pad_width, mode='constant', constant_values=0)
    new_shape = padded_array.shape

    # Iterate over chunks
    for z in range(0, new_shape[0], chunk_size):
        for y in range(0, new_shape[1], chunk_size):
            for x in range(0, new_shape[2], chunk_size):
                chunk = padded_array[
                    z:z+chunk_size,
                    y:y+chunk_size,
                    x:x+chunk_size
                ]
                filename = os.path.join(output_dir, f"chunk-{x//chunk_size}-{y//chunk_size}-{z//chunk_size}.bin")
                chunk.tofile(filename)

    print(f"Chunks saved to '{output_dir}'")

# Example usage:
if __name__ == "__main__":
    # Create a dummy array of size 70x65x80 with random uint32 values
    data = np.random.randint(0, 1000, size=(70, 65, 80), dtype=np.uint32)
    save_chunks(data, chunk_size=32, output_dir="chunks")
