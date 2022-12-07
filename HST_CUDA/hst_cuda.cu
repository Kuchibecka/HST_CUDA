#include <stdio.h>
#include <cuda.h>
#include <time.h>
#include <iostream>
#include <fstream>

__global__ void kernel(int* vec, int* mat, int* out, const int N, const int M) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	int sum = 0;
	if (tid < M) {
		for (int i = 0; i < N; i++)
			sum += vec[i] * mat[(i * M) + tid];
		out[tid] = sum;
	}
}

void init_array(int* a, const int N);
void init_mat(int* a, const int N, const int M);
void print_array(int* a, const int N, char* d);
void print_mat(int* a, const int N, const int M, char* d);
void generateMatrixInFile(std::string fileName, int fileSize);

using namespace std;

int main(void) {
	int* a, * b, * c;
	int* dev_a, * dev_b, * dev_c;
	int choice1 = 0, choice2 = 0;
	int N, M;

	//std::cin >> choice1;
	//std::cin >> choice2;

	printf("Enter size in Mb if you want to generate a new vector file\n");
	printf("Enter \"0\" if you wanna keep old vector file\n");
	std::cin >> choice1;

	if (choice1) {
		generateMatrixInFile("inV.txt", choice1);
		printf("Generated %d Mb inV.txt file with input vector\n", choice1);
	}

	printf("Enter size in Mb if you want to generate a new matrix file\n");
	printf("Enter \"0\" if you wanna keep old matrix file\n");
	std::cin >> choice2;

	if (choice2) {
		generateMatrixInFile("inM.txt", choice2);
		printf("Generated %d Mb inM.txt file with input matrix\n", choice2);
	}

	printf("Enter vector length (N)\n");
	std::cin >> N;

	printf("Enter matrix size (M)\n");
	std::cin >> M;

	a = (int*)malloc(sizeof(int) * N);
	b = (int*)malloc(sizeof(int) * N * M);
	c = (int*)malloc(sizeof(int) * M);
	printf("Allocated memory for result vector, input vector and matrix\n");

	init_array(a, N);
	printf("Readed input vector from file\n");
	init_mat(b, N, M);
	printf("Readed input matrix from file\n");

	// printf("initial data:\n");
	// print_array(a, N);
	// print_mat(b, N, M, "matrix");

	cudaMalloc((void**)&dev_a, sizeof(int) * N);
	cudaMalloc((void**)&dev_b, sizeof(int) * N * M);
	cudaMalloc((void**)&dev_c, sizeof(int) * M);
	printf("CUDA allocated memory for result vector, matrix and input vector\n");

	cudaMemcpy(dev_a, a, sizeof(int) * N, cudaMemcpyHostToDevice);
	cudaMemcpy(dev_b, b, sizeof(int) * N * M, cudaMemcpyHostToDevice);
	printf("CUDA copied input matrix and vector\n");

	printf("\n\nRunning kernel with M = %d, N = ...\n\n");

	cudaEvent_t start, stop;
	float gpuTime = 0.0;
	cudaEventCreate(&start);
	cudaEventCreate(&stop);
	cudaEventRecord(start, 0);

	kernel << <M / 1024 + 1, 1024 >> > (dev_a, dev_b, dev_c, N, M);

	cudaEventRecord(stop, 0);
	cudaEventSynchronize(stop);
	cudaEventElapsedTime(&gpuTime, start, stop);
	printf("time on GPU = %.2f ms \n", gpuTime);
	cudaEventDestroy(start);
	cudaEventDestroy(stop);

	cudaMemcpy(c, dev_c, sizeof(int) * M, cudaMemcpyDeviceToHost);

	cudaFree(dev_a);
	cudaFree(dev_b);
	cudaFree(dev_c);

	FILE* log;
	log = fopen("log.txt", "a");
	fprintf(log, "Matrix[%d x %d], vector[%d], elapsed time: %.2f ms\n", N, M, N, gpuTime);
	printf("New log appended to log.txt\n");

	FILE* out;
	out = fopen("out.txt", "w");
	for (int i = 0; i < M; i++)
		fprintf(out, "V[%d]: %d\n", i, c[i]);
	printf("Result data written to out.txt\n");

	fclose(log);
	fclose(out);
	free(a);
	free(b);
	free(c);
	//print_array(c, M);

	return 0;
};

void generateMatrixInFile(std::string fileName, int fileSize) {
	srand(time(NULL));
	int bytesFileSize = fileSize * 1024 * 1024;
	int matrixSize = sqrt(bytesFileSize / 4);

	FILE* fd;
	fd = fopen(fileName.c_str(), "w+b");

	for (int i = 0; i < matrixSize; i++) {
		for (int j = 0; j < matrixSize; j++)
			fprintf(fd, "%d ", 1 + rand() % 100);
	}
	fclose(fd);
}

void init_array(int* a, const int N) {
	FILE* inV = fopen("inV.txt", "r");
	if (!inV) {
		printf("Error opening input matrix file");
		exit(1);
	}
	for (int i = 0; i < N; i++) {
		fscanf(inV, "%d", &a[i]);
	}
	fclose(inV);
}

void print_array(int* a, const int N) {
	int i;
	for (i = 0; i < N; i++)
		printf("\nV[%d]: %d", i, a[i]);
	printf("\n");
}

void init_mat(int* a, const int N, const int M) {
	FILE* inM = fopen("inM.txt", "r");
	if (!inM) {
		printf("Error opening input matrix file");
		exit(1);
	}

	for (int i = 0; i < N; i++) {
		for (int j = 0; j < M; j++) {
			fscanf(inM, "%d", &a[i * M + j]);
		}
	}
	fclose(inM);
}

void print_mat(int* a, const int N, const int M, char* d) {
	int i, j;
	for (i = 0; i < N; i++) {
		printf("\n%s[%d]:", d, i);
		for (j = 0; j < M; j++)
			printf("\t%d", a[i * M + j]);
	}
	printf("\n");
}