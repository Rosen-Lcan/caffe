#ifndef CAFFE_MULTILABEL_SIGMOID_CROSS_ENTROPY_LOSS_LAYER_HPP_
#define CAFFE_MULTILABEL_SIGMOID_CROSS_ENTROPY_LOSS_LAYER_HPP_

#include <vector>

#include "caffe/blob.hpp"
#include "caffe/layer.hpp"
#include "caffe/proto/caffe.pb.h"

#include "caffe/layers/loss_layer.hpp"
#include "caffe/layers/sigmoid_layer.hpp"

namespace caffe {
template <typename Dtype>
class MultiLabelLossLayer: public LossLayer<Dtype> {
    public:
        explicit MultiLabelLossLayer( const LayerParameter& param)
            :LossLayer<Dtype>(param),
                sigmoid_layer_(new SigmoidLayer<Dtype>(param)),
                sigmoid_output_(new Blob<Dtype>()){}
        virtual void LayerSetUp(const vector<Blob<Dtype>*>& bottom,
            const vector<Blob<Dtype>*>& top);
        virtual void Reshape(const vector<Blob<Dtype>*>& bottom,
            const vector<Blob<Dtype>*>& top);

        virtual inline const char* type() const { return "MultiLabelLoss"; }
        virtual inline int MaxTopBlobs() const { return 2;}
        virtual inline int ExactNumBottomBlobs() const { return 2;}
        
        virtual inline bool AllowForceBackward( const int bottom_index) const {
            return bottom_index != 1;
        }
        
    protected:
        virtual void Forward_cpu( const vector<Blob<Dtype>*>& bottom,
                const vector<Blob<Dtype>*>& top);
        virtual void Forward_gpu( const vector<Blob<Dtype>*>& bottom,
                const vector<Blob<Dtype>*>& top);

        virtual void Backward_cpu(const vector<Blob<Dtype>*>& top,
                const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom);
         virtual void Backward_gpu(const vector<Blob<Dtype>*>& top,
                const vector<bool>& propagate_down, const vector<Blob<Dtype>*>& bottom);
       
        shared_ptr< SigmoidLayer<Dtype> > sigmoid_layer_;
        shared_ptr< Blob<Dtype> > sigmoid_output_;
        vector<Blob<Dtype>*> sigmoid_bottom_vec_;
        vector<Blob<Dtype>*> sigmoid_top_vec_;
};

}  // namespace caffe

#endif  // CAFFE_MULTILABEL_SIGMOID_CROSS_ENTROPY_LOSS_LAYER_HPP_
