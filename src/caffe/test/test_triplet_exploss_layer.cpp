/*

this file is reference to tangwei

*/
#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <vector>

#include "gtest/gtest.h"

#include "caffe/blob.hpp"
#include "caffe/common.hpp"
#include "caffe/filler.hpp"
#include "caffe/layers/triplet_exploss_layer.hpp"

#include "caffe/test/test_caffe_main.hpp"
#include "caffe/test/test_gradient_check_util.hpp"

namespace caffe {

template < typename TypeParam>
class TripletExpLossLayerTest : public MultiDeviceTest<TypeParam> {
    typedef typename TypeParam::Dtype Dtype;

    protected:
        TripletExpLossLayerTest()
            : blob_bottom_data_i_( new Blob<Dtype>(100, 20, 1, 1)),
              blob_bottom_data_j_( new Blob<Dtype>(100, 20, 1, 1)),
              blob_bottom_data_k_( new Blob<Dtype>(100, 20, 1, 1)),
              // blob_bottom_y_( new Blob<Dtype>(512, 1, 1, 1)),
              blob_top_loss_( new Blob<Dtype>()) {
            // fill the values
            FillerParameter filler_param;
            filler_param.set_min(-1.0);
            filler_param.set_max(1.0);
            UniformFiller<Dtype> filler( filler_param );
            filler.Fill( this->blob_bottom_data_i_ );
            filler.Fill( this->blob_bottom_data_j_ );
            filler.Fill( this->blob_bottom_data_k_ );
            blob_bottom_vec_.push_back( blob_bottom_data_i_ );
            blob_bottom_vec_.push_back( blob_bottom_data_j_ );
            blob_bottom_vec_.push_back( blob_bottom_data_k_ );
            // blob_bottom_vec_.push_back( blob_bottom_y_ );
            // ignore the blob_bottom_y
            /*for ( int i = 0; i < blob_bottom_y_->count(); i++)
            {
                blob_bottom_y_->mutable_cpu_data()[i] = caffe_rng_rand() % 2; // 0 or 1
            }*/
            blob_top_vec_.push_back( blob_top_loss_ );
        }
      virtual ~TripletExpLossLayerTest()
        {
            delete blob_bottom_data_i_;
            delete blob_bottom_data_j_;
            delete blob_bottom_data_k_;
            delete blob_top_loss_;
        }      

        Blob<Dtype>* const blob_bottom_data_i_;
        Blob<Dtype>* const blob_bottom_data_j_;
        Blob<Dtype>* const blob_bottom_data_k_;
        // Blob<Dtype>* const blob_bottom_y_;
        Blob<Dtype>* const blob_top_loss_;
        vector<Blob<Dtype>*> blob_bottom_vec_;
        vector<Blob<Dtype>*> blob_top_vec_;
};

TYPED_TEST_CASE(TripletExpLossLayerTest, TestDtypesAndDevices);

TYPED_TEST( TripletExpLossLayerTest, TestForward){
    typedef typename TypeParam::Dtype Dtype;
    LayerParameter layer_param;
    TripletExpLossParameter *triplet_exploss_param = layer_param.mutable_triplet_exploss_param();
    float margin = 0.5;
    triplet_exploss_param->set_margin(margin);
    TripletExpLossLayer<Dtype> layer(layer_param);
    cout << "lidangwei: setup" << endl;
    layer.SetUp(this->blob_bottom_vec_, this->blob_top_vec_);
    cout << "lidangwei: forward" << endl;
    layer.Forward(this->blob_bottom_vec_, this->blob_top_vec_);
    cout << "lidangwei: forward ok" << endl;
    // manually compute to compare
    // const Dtype margin = layer_param.triplet_loss_param().margin();
    const int num = this->blob_bottom_data_i_->num();
    const int channels = this->blob_bottom_data_i_->channels();
    Dtype loss(0.0);
    Dtype mdist(0.0);
    for (int i = 0; i < num; i++)
    {
        Dtype dist_sq_ij(0.0);
        Dtype dist_sq_ik(0.0);
        for( int j = 0; j < channels; j++)
        {
            Dtype diff_ij = this->blob_bottom_data_i_->cpu_data()[i*channels+j] - 
                    this->blob_bottom_data_j_->cpu_data()[i*channels+j];
            dist_sq_ij += diff_ij*diff_ij;
            Dtype diff_ik = this->blob_bottom_data_i_->cpu_data()[i*channels+j] -
                    this->blob_bottom_data_k_->cpu_data()[i*channels+j];
            dist_sq_ik += diff_ik*diff_ik;
        }
        mdist = std::max(Dtype(0.0), margin + dist_sq_ij - dist_sq_ik);
        loss += exp(mdist * 0.5) - 1.0;
    } 
    loss /= static_cast<Dtype>(num);
    EXPECT_NEAR(this->blob_top_loss_->cpu_data()[0], loss, 1e-6); 
}

TYPED_TEST(TripletExpLossLayerTest, TestGradient) {
    typedef typename TypeParam::Dtype Dtype;
    LayerParameter layer_param;
    TripletExpLossLayer<Dtype> layer(layer_param);
    layer.SetUp(this->blob_bottom_vec_, this->blob_top_vec_ );
    GradientChecker<Dtype> checker(1e-2, 1e-2, 1701);
    // check gradient for first two layer
    checker.CheckGradientExhaustive(&layer, this->blob_bottom_vec_,
        this->blob_top_vec_, 0);
    checker.CheckGradientExhaustive(&layer, this->blob_bottom_vec_,
        this->blob_top_vec_, 1);
    checker.CheckGradientExhaustive(&layer, this->blob_bottom_vec_,
        this->blob_top_vec_, 2);

}

} // end namespace caffe


