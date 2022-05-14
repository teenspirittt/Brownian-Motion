#include <glut.h>
#include <math.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>

#include "cuda_runtime.h"
#include "curand.h"
#include "curand_kernel.h"
#include "device_launch_parameters.h"

#define MAX_FLAKES 3000
#define SPEED 0.09
#define MAX_X 1280
#define MAX_Y 720
#define MIN_X -640
#define MIN_Y -360

void drawPoint();
void spawnPoint();
void movePoint(int i);

typedef struct snowFlake {
  float posX;
  float posY;
  float destX;
  float destY;
} snowFlake;

snowFlake* flake = NULL;
snowFlake* dev_flake = NULL;

__global__ void kernel(unsigned int seed, snowFlake* flake) {
  unsigned i = threadIdx.x + blockIdx.x * blockDim.x;

  int idx = threadIdx.x + blockDim.x * blockIdx.x;
  curandState_t state;
  curand_init(seed + i, 0, 0, &state);

  int randX = MIN_X + curand(&state) % MAX_X;
  int randY = MIN_Y + curand(&state) % MAX_Y;

  if (flake[i].posX >= flake[i].destX - 20 &&
      flake[i].posX <= flake[i].destX + 20 &&
      flake[i].posY >= flake[i].destY - 20 &&
      flake[i].posY <= flake[i].destY + 20) {
    // flake[i].destX = flake[(i + 1) % MAX_FLAKES].posY;
    // flake[i].destY = flake[(i + 1) % MAX_FLAKES].posY;
    flake[i].destX = randX;
    flake[i].destY = randY;
  } else {
    double dx = (flake[i].destX - flake[i].posX) / 10.0;
    double dy = (flake[i].destY - flake[i].posY) / 10.0;
    flake[i].posX = flake[i].posX + dx * SPEED;
    flake[i].posY = flake[i].posY + dy * SPEED;
  }
}

void drawPoint() {
  glPushMatrix();
  glEnable(GL_POINT_SMOOTH);
  glPointSize(1);
  glClear(GL_COLOR_BUFFER_BIT);
  glBegin(GL_POINTS);
  glColor3f(1, 1, 1);

  cudaMemcpy(dev_flake, flake, sizeof(snowFlake) * MAX_FLAKES,
             cudaMemcpyHostToDevice);
  kernel<<<5, 1000>>>(time(NULL), dev_flake);
  cudaMemcpy(flake, dev_flake, sizeof(snowFlake) * MAX_FLAKES,
             cudaMemcpyDeviceToHost);
  cudaDeviceSynchronize();
  for (int i = 0; i < MAX_FLAKES; ++i) {
    glColor3f(0, (float)(flake[i].posX + 640) / 1280,
              1 - (float)(flake[i].posX + 640) / 1280);
    glVertex2f(flake[i].posX, (flake[i].posY));
  }

  glEnd();
  glPopMatrix();
  glutSwapBuffers();
}

void spawnPoint() {
  glClearColor(0, 0, 0, 0);
  glScalef((float)1 / 640, (float)1 / 360, 1);
  glMatrixMode(GL_PROJECTION);
  flake = (snowFlake*)malloc(sizeof(snowFlake) * MAX_FLAKES);
  cudaMalloc((void**)&dev_flake, sizeof(snowFlake) * MAX_FLAKES);

  for (int i = 0; i < MAX_FLAKES; ++i) {
    flake[i].posX = (-640 + rand() % 1280);
    flake[i].posY = (-360 + rand() % 720);
    // flake[i].destX = (-640 + rand() % 1280);
    // flake[i].destY = (-640 + rand() % 1280);
    flake[i].destX = 0;
    flake[i].destY = 0;
  }
  cudaMemcpy(dev_flake, flake, sizeof(snowFlake) * MAX_FLAKES,
             cudaMemcpyHostToDevice);
  glLoadIdentity();
  glMatrixMode(GL_MODELVIEW);
}

void timer(int value) {
  glutPostRedisplay();
  glutTimerFunc(30, timer, 0);
}

int main(int argc, char** argv) {
  glutInit(&argc, argv);  // Setting up OpenGL
  glutInitDisplayMode(GLUT_DOUBLE | GLUT_RGB);
  glutInitWindowSize(1280, 720);
  glutInitWindowPosition(400, 150);
  glutCreateWindow("takov put'");
  glutDisplayFunc(drawPoint);
  glutTimerFunc(30, timer, 0);
  spawnPoint();
  glutMainLoop();
  free(flake);
  cudaFree(dev_flake);
}
