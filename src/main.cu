#include <pthread.h>
#include <stdio.h>
#include <iostream>

//const int N = 1 << 20;
const int N = 10;

__global__ void kernel(float *x, int n)
{
    int tid = threadIdx.x + blockIdx.x * blockDim.x;
    for (int i = tid; i < n; i += blockDim.x * gridDim.x) {
        x[i] = sqrt(pow(3.14159,i));
    }
}

__global__ void idxTest(float *x, float *data, int n, uint incr)
{
	size_t tid = threadIdx.x + blockIdx.x * blockDim.x;
	size_t stride = blockDim.x * gridDim.x;
	while (tid < n)
	{
		//x[tid] = static_cast<float>(tid);
		x[tid] = data[tid] + incr;
		tid += stride;
	}
}

/*int main()
{
    const int num_streams = 8;

    cudaStream_t streams[num_streams];
    float *data[num_streams];

    for (int i = 0; i < num_streams; i++) {
        cudaStreamCreate(&streams[i]);

        cudaMalloc(&data[i], N * sizeof(float));

        // launch one worker kernel per stream
        kernel<<<1, 64, 0, streams[i]>>>(data[i], N);

        // launch a dummy kernel on the default stream
        kernel<<<1, 1>>>(0, 0);
    }

    cudaDeviceReset();

    return 0;
}*/

struct cuda_streams_arg {
	cudaStream_t *stream;
    float *data;
    uint threadId;
};

void *launch_kernel(void *args)
{

	cuda_streams_arg *thread_arg = static_cast<cuda_streams_arg *>(args);

	cudaStream_t *currentStream = static_cast<cudaStream_t *>(thread_arg->stream);
	cudaStreamCreate(currentStream);

    float *data;
    cudaMalloc(&data, N * sizeof(float));

    //kernel<<<1, 64, 0, *currentStream>>>(data, thread_arg->data, N);
    idxTest<<<2, 4, 0, *currentStream>>>(data, thread_arg->data, N, thread_arg->threadId);

    cudaStreamSynchronize(0);

    float *host_data = (float *)(malloc(N * sizeof(float)));
    cudaMemcpy(host_data, data, N*sizeof(float), cudaMemcpyDeviceToHost);

    for(int i = 0; i < N; ++i)
    	std::cout << host_data[i] << " ";

    std::cout << std::endl;

    return NULL;
}


int main()
{
    const int num_threads = 4;

    pthread_t threads[num_threads];
    cudaStream_t streams[num_threads];
    cuda_streams_arg stream_args[num_threads];

    float host_globalData[N];
    for (size_t idx = 0; idx < N; ++idx)
    {
    	host_globalData[idx] = idx*2;
    	std::cout << host_globalData[idx] << " ";
    }
    std::cout << std::endl;

    float *dev_globalData;
    cudaMalloc(&dev_globalData, 10*sizeof(float));
    cudaMemcpy(dev_globalData, host_globalData, 10*sizeof(float), cudaMemcpyHostToDevice);


    for (int i = 0; i < num_threads; i++) {
    	stream_args[i].stream = &streams[i];
    	stream_args[i].data = dev_globalData;
    	stream_args[i].threadId = i;

    	if (pthread_create(&threads[i], NULL, launch_kernel, &stream_args[i])) {
            fprintf(stderr, "Error creating threadn");
            return 1;
        }
    }

    for (int i = 0; i < num_threads; i++) {
        if(pthread_join(threads[i], NULL)) {
            fprintf(stderr, "Error joining threadn");
            return 2;
        }
    }

    cudaDeviceReset();

    return 0;
}
