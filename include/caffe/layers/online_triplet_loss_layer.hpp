#ifndef CAFFE_ONLINE_TRIPLET_LOSS_LAYER_HPP_
#define CAFFE_ONLINE_TRIPLET_LOSS_LAYER_HPP_

#include <vector>

#include "caffe/blob.hpp"
#include "caffe/layer.hpp"
#include "caffe/proto/caffe.pb.h"

#include "caffe/layers/loss_layer.hpp"
#include "caffe/layers/softmax_layer.hpp"

namespace caffe {


class Triplet {
public:
  explicit Triplet(int first, int second, int third) :
    first_(first), second_(second), third_(third) {
  }
  int first_;
  int second_;
  int third_;
};

/**
* @brief Computes the hinge loss for learning to rank with triplet sampling.
*        The triplet sampling scheme is similar with FaceNet. when \mu=1, the loss is same.
*    "Distance Metric Learning for Large Margin Nearest Neighbor Classification"
* @param bottom input Blob vector (length 2)
*   -# @f$ (N \times C \times 1 \times 1) @f$
*      the features @f$ x \in [-\infty, +\infty]@f$
*   -# @f$ (N \times 1 \times 1 \times 1) @f$
*      the labels @f$ l @f$, an integer-valued Blob
* @param top output Blob vector (length 1)
*   -# @f$ (1 \times 1 \times 1 \times 1) @f$
*      the computed hinge loss: @f$ E = \mu*rank_loss+(1-\mu)*pair_loss
*      @f$
*/
template <typename Dtype>
class OnlineTripletLossLayer : public LossLayer<Dtype> {
public:
  explicit OnlineTripletLossLayer(const LayerParameter& param)
    : LossLayer<Dtype>(param) {}
  virtual void LayerSetUp(const vector<Blob<Dtype>*>& bottom,
    const vector<Blob<Dtype>*>& top);
  virtual void Reshape(const vector<Blob<Dtype>*>& bottom,
    const vector<Blob<Dtype>*>& top);

  virtual inline const char* type() const { return "OnlineTripletLoss"; }
  virtual inline int ExactNumTopBlobs() const { return -1; }
  virtual inline int MinTopBlobs() const { return 1; }
  virtual inline int MaxTopBlobs() const { return 2; }
protected:
  virtual void Forward_cpu(const vector<Blob<Dtype>*>& bottom,
    const vector<Blob<Dtype>*>& top);
  virtual void Forward_gpu(const vector<Blob<Dtype>*>& bottom,
    const vector<Blob<Dtype>*>& top);

  /**
  * @brief Computes the softmax loss error gradient w.r.t. the predictions.
  *
  * Gradients cannot be computed with respect to the label inputs (bottom[1]),
  * so this method ignores bottom[1] and requires !propagate_down[1], crashing
  * if propagate_down[1] is set.
  */
  virtual void Backward_cpu(const vector<Blob<Dtype>*>& top,
    const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom);
  virtual void Backward_gpu(const vector<Blob<Dtype>*>& top,
    const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom);


  Dtype num_triplets_;
  vector<Triplet> triplets_;
  vector<pair<int, int> > pos_pairs_;
  Blob<Dtype> dist_;
  shared_ptr<SyncedMemory> aggregator_;
  Dtype margin_;
  Dtype mu_; //E = \mu*rank_loss + (1 - \mu)*pair_loss
};


}  // namespace caffe

#endif  // CAFFE_ONLINE_TRIPLET_LOSS_LAYER_HPP_