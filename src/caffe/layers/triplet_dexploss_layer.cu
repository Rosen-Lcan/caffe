/*
* triplet_loss_layer.cu
*
*/

#include <algorithm>
#include <vector>


#include "caffe/layers/triplet_dexploss_layer.hpp"
#include "caffe/util/math_functions.hpp"

namespace caffe {

  template <typename Dtype>
  void TripletDExpLossLayer<Dtype>::Forward_gpu(
    const vector<Blob<Dtype>*>& bottom, const vector<Blob<Dtype>*>& top) {
    const int count = bottom[0]->count();
    
    Dtype* sampleWv = NULL;
    Dtype* exp_weight = exp_weight_.mutable_cpu_data();
    // Dtype* dexp_weight = dexp_weight_.mutable_cpu_data();
    Blob<Dtype> sampleWv_Blob;
    if(bottom.size() == 4)
    {
        sampleWv = bottom[3]->mutable_cpu_data();
    }else
    {
        sampleWv_Blob.Reshape(bottom[0]->num(), 1, 1, 1);
        sampleWv = sampleWv_Blob.mutable_cpu_data();
        for(int i= 0; i<bottom[0]->num(); i++) sampleWv[i] = Dtype(1);
    }
    caffe_gpu_sub(
      count,
      bottom[0]->gpu_data(),  // a
      bottom[1]->gpu_data(),  // p
      diff_ap_.mutable_gpu_data());  // a_i-p_i
    caffe_gpu_sub(
      count,
      bottom[0]->gpu_data(),  // a
      bottom[2]->gpu_data(),  // n
      diff_an_.mutable_gpu_data());  // a_i-n_i
    caffe_gpu_sub(
      count,
      bottom[1]->gpu_data(),  // p
      bottom[2]->gpu_data(),  // n
      diff_pn_.mutable_gpu_data());  // p_i-n_i
    // add support for double propagation
    caffe_gpu_sub(
      count,
      bottom[1]->gpu_data(),  // a
      bottom[0]->gpu_data(),  // p
      d_diff_ap_.mutable_gpu_data());  // a_i-p_i
    caffe_gpu_sub(
      count,
      bottom[1]->gpu_data(),  // a
      bottom[2]->gpu_data(),  // n
      d_diff_an_.mutable_gpu_data());  // a_i-n_i
    caffe_gpu_sub(
      count,
      bottom[0]->gpu_data(),  // p
      bottom[2]->gpu_data(),  // n
      d_diff_pn_.mutable_gpu_data());  // p_i-n_i

    caffe_gpu_powx(
      count,
      diff_ap_.mutable_gpu_data(),  // a_i-p_i
      Dtype(2),
      diff_sq_ap_.mutable_gpu_data());  // (a_i-p_i)^2
    caffe_gpu_gemv(
      CblasNoTrans,
      bottom[0]->num(),
      bottom[0]->channels(),
      Dtype(1.0),                                         //alpha
      diff_sq_ap_.gpu_data(),  // (a_i-p_i)^2                // A
      summer_vec_.gpu_data(),                             // x
      Dtype(0.0),                                         //belta
      dist_sq_ap_.mutable_gpu_data());  // \Sum (a_i-p_i)^2  //y
    // add support for propagation for d-
    caffe_gpu_powx(
      count,
      d_diff_ap_.mutable_gpu_data(),  // a_i-p_i
      Dtype(2),
      d_diff_sq_ap_.mutable_gpu_data());  // (a_i-p_i)^2
    caffe_gpu_gemv(
      CblasNoTrans,
      bottom[0]->num(),
      bottom[0]->channels(),
      Dtype(1.0),                                         //alpha
      d_diff_sq_ap_.gpu_data(),  // (a_i-p_i)^2                // A
      summer_vec_.gpu_data(),                             // x
      Dtype(0.0),                                         //belta
      d_dist_sq_ap_.mutable_gpu_data());  // \Sum (a_i-p_i)^2  //y

    caffe_gpu_powx(
      count,
      diff_an_.mutable_gpu_data(),  // a_i-n_i
      Dtype(2),
      diff_sq_an_.mutable_gpu_data());  // (a_i-n_i)^2
    caffe_gpu_gemv(
      CblasNoTrans,
      bottom[0]->num(),
      bottom[0]->channels(),
      Dtype(1.0),                                         //alpha
      diff_sq_an_.gpu_data(),  // (a_i-n_i)^2                // A
      summer_vec_.gpu_data(),                             // x
      Dtype(0.0),                                         //belta
      dist_sq_an_.mutable_gpu_data());  // \Sum (a_i-n_i)^2  //y
    // add support for d-propagation
    caffe_gpu_powx(
      count,
      d_diff_an_.mutable_gpu_data(),  // a_i-n_i
      Dtype(2),
      d_diff_sq_an_.mutable_gpu_data());  // (a_i-n_i)^2
    caffe_gpu_gemv(
      CblasNoTrans,
      bottom[0]->num(),
      bottom[0]->channels(),
      Dtype(1.0),                                         //alpha
      d_diff_sq_an_.gpu_data(),  // (a_i-n_i)^2                // A
      summer_vec_.gpu_data(),                             // x
      Dtype(0.0),                                         //belta
      d_dist_sq_an_.mutable_gpu_data());  // \Sum (a_i-n_i)^2  //y

    Dtype margin = this->layer_param_.triplet_dexploss_param().margin();

    Dtype loss(0.0);
    Dtype mdist1(0.0);
    Dtype mdist2(0.0);
    Dtype mdist(0.0);
    for (int i = 0; i < bottom[0]->num(); ++i) {
      mdist1 = std::max(margin + dist_sq_ap_.cpu_data()[i] - dist_sq_an_.cpu_data()[i], Dtype(0.0));
      mdist1 = mdist1/2;
      // add support for propagation
      mdist2 = std::max(margin + d_dist_sq_ap_.cpu_data()[i] - d_dist_sq_an_.cpu_data()[i], Dtype(0.0));
      mdist2 = mdist2/2;
      mdist = mdist1 + mdist2;
      caffe_exp(1, &mdist, &(exp_weight[i]));
      
      loss += sampleWv[i]*(exp_weight[i] - 1.0);
    }
    loss = loss / static_cast<Dtype>(bottom[0]->num());
    top[0]->mutable_cpu_data()[0] = loss;
  }

  template <typename Dtype>
  __global__ void CLLBackward(const int count, const int channels,
                              const Dtype margin, const Dtype alpha,
                              const Dtype* diff, const Dtype* dist_sq_ap_, const Dtype* dist_sq_an_,
                              Dtype *sampleWv_cuda, Dtype *exp_weight_cuda, Dtype *bottom_diff) {
    CUDA_KERNEL_LOOP(i, count) {
      int n = i / channels;  // the num index, to access dist_sq_ap_ and dist_sq_an_
      Dtype mdist(0.0);
      mdist = margin + dist_sq_ap_[n] - dist_sq_an_[n];
      if (mdist > 0.0) {
        bottom_diff[i] = alpha*sampleWv_cuda[n]*exp_weight_cuda[n]*diff[i];
        // bottom_diff[i] = alpha*diff[i];
      }
      else {
        bottom_diff[i] = 0;
      }
    }
  }
  // add support for d-
  template <typename Dtype>
  __global__ void DCLLBackward(const int count, const int channels,
                              const Dtype margin, const Dtype alpha,
                              const Dtype* diff, const Dtype* dist_sq_ap_, const Dtype* dist_sq_an_,
                              Dtype *sampleWv_cuda, Dtype *dexp_weight_cuda, Dtype *bottom_diff) {
    CUDA_KERNEL_LOOP(i, count) {
      int n = i / channels;  // the num index, to access dist_sq_ap_ and dist_sq_an_
      Dtype mdist(0.0);
      mdist = margin + dist_sq_ap_[n] - dist_sq_an_[n];
      if (mdist > 0.0) {
        bottom_diff[i] = bottom_diff[i] + alpha*sampleWv_cuda[n]*dexp_weight_cuda[n]*diff[i];
        // bottom_diff[i] = alpha*diff[i];
      }
    }
  }

  template <typename Dtype>
  void TripletDExpLossLayer<Dtype>::Backward_gpu(const vector<Blob<Dtype>*>& top,
                                             const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom) {
    Dtype margin = this->layer_param_.triplet_dexploss_param().margin();
    const int count = bottom[0]->count();
    const int channels = bottom[0]->channels();
    // the weight triplet loss 
    Dtype* sampleWv = NULL;
    Dtype* exp_weight = exp_weight_.mutable_gpu_data();
    Blob<Dtype> sampleWv_Blob;
    if(bottom.size() == 4)
    {
        sampleWv = bottom[3]->mutable_gpu_data();
    }else
    {
        sampleWv_Blob.Reshape(bottom[0]->num(), 1, 1, 1);
        sampleWv = sampleWv_Blob.mutable_cpu_data();
        for(int i= 0; i<bottom[0]->num(); i++) sampleWv[i] = Dtype(1);
        sampleWv = sampleWv_Blob.mutable_gpu_data();
    }

    for (int i = 0; i < 3; ++i) {
      if (propagate_down[i]) {
        const Dtype sign = (i < 2) ? -1 : 1;
        const Dtype alpha = sign * top[0]->cpu_diff()[0] /
          static_cast<Dtype>(bottom[0]->num());
        if (i == 0) {
          // NOLINT_NEXT_LINE(whitespace/operators)
          CLLBackward<Dtype> << <CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS >> >(
            count, channels, margin, alpha,
            diff_pn_.gpu_data(),  // the cached eltwise difference between p and n
            dist_sq_ap_.gpu_data(),  // the cached square distance between a and p
            dist_sq_an_.gpu_data(),  // the cached square distance between a and n
            sampleWv, // the sample's weight
            exp_weight, // the loss 
            bottom[i]->mutable_gpu_diff());
          CUDA_POST_KERNEL_CHECK;
          // add support propagation for d-
          // NOLINT_NEXT_LINE(whitespace/operators)
          DCLLBackward<Dtype> << <CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS >> >(
            count, channels, margin, alpha,
            d_diff_ap_.gpu_data(),  // the cached eltwise difference between p and n
            d_dist_sq_ap_.gpu_data(),  // the cached square distance between a and p
            d_dist_sq_an_.gpu_data(),  // the cached square distance between a and n
            sampleWv, // the sample's weight
            exp_weight, // the loss 
            bottom[i]->mutable_gpu_diff());
          CUDA_POST_KERNEL_CHECK;
        }
        else if (i == 1) {
          // NOLINT_NEXT_LINE(whitespace/operators)
          CLLBackward<Dtype> << <CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS >> >(
            count, channels, margin, alpha,
            diff_ap_.gpu_data(),  // the cached eltwise difference between a and p
            dist_sq_ap_.gpu_data(),  // the cached square distance between a and p
            dist_sq_an_.gpu_data(),  // the cached square distance between a and n
            sampleWv, // the sample's weight
            exp_weight, // the loss
            bottom[i]->mutable_gpu_diff());
          CUDA_POST_KERNEL_CHECK;
          // add support for d-propatation
          // NOLINT_NEXT_LINE(whitespace/operators)
          DCLLBackward<Dtype> << <CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS >> >(
            count, channels, margin, alpha,
            d_diff_pn_.gpu_data(),  // the cached eltwise difference between a and p
            d_dist_sq_ap_.gpu_data(),  // the cached square distance between a and p
            d_dist_sq_an_.gpu_data(),  // the cached square distance between a and n
            sampleWv, // the sample's weight
            exp_weight, // the loss
            bottom[i]->mutable_gpu_diff());
          CUDA_POST_KERNEL_CHECK;
        }
        else if (i == 2) {
          // NOLINT_NEXT_LINE(whitespace/operators)
          CLLBackward<Dtype> << <CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS >> >(
            count, channels, margin, alpha,
            diff_an_.gpu_data(),  // the cached eltwise difference between a and n
            dist_sq_ap_.gpu_data(),  // the cached square distance between a and p
            dist_sq_an_.gpu_data(),  // the cached square distance between a and n
            sampleWv, // the weight's wight
            exp_weight, // the loss
            bottom[i]->mutable_gpu_diff());
          CUDA_POST_KERNEL_CHECK;
          // NOLINT_NEXT_LINE(whitespace/operators)
          DCLLBackward<Dtype> << <CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS >> >(
            count, channels, margin, alpha,
            d_diff_pn_.gpu_data(),  // the cached eltwise difference between a and n
            d_dist_sq_ap_.gpu_data(),  // the cached square distance between a and p
            d_dist_sq_an_.gpu_data(),  // the cached square distance between a and n
            sampleWv, // the weight's wight
            exp_weight, // the loss
            bottom[i]->mutable_gpu_diff());
          CUDA_POST_KERNEL_CHECK;

        } // end if
      } // end propagation[i]
    } // end for i=1:3
    // release the resource, automally
  }

  INSTANTIATE_LAYER_GPU_FUNCS(TripletDExpLossLayer);

}  // namespace caffe