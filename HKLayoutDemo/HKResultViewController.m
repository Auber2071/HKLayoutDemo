//
//  HKResultViewController.m
//  HKLayoutDemo
//
//  Created by hankai on 2020/7/22.
//  Copyright © 2020 Edward. All rights reserved.
//

#import "HKResultViewController.h"
#import "AFHTTPSessionManager.h"
#import "AFURLSessionManager.h"

@interface HKResultViewController ()

@end

@implementation HKResultViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark - UISearchResultsUpdating
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    searchController.searchResultsController.view.hidden = NO;
}




- (void)upLoadImageWithStream {
    UIImage *yourImage = [[UIImage alloc] init];
    
    // 假设你已经有了图片的NSData对象
    NSData *imageData = UIImageJPEGRepresentation(yourImage, 0.8);
    
    // 每个块的大小，你可以根据需求调整
    NSUInteger chunkSize = 1024 * 1024; // 例如，每个块1MB
    
    // 计算块的数量
    NSUInteger totalChunks = (imageData.length + chunkSize - 1) / chunkSize;
    
    // 记录已经上传的块
    NSMutableIndexSet *uploadedChunks = [NSMutableIndexSet indexSet];
    
    // 上传任务
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    for (NSUInteger chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        NSRange chunkRange = NSMakeRange(chunkIndex * chunkSize, MIN(chunkSize, imageData.length - chunkIndex * chunkSize));
        NSData *chunkData = [imageData subdataWithRange:chunkRange];
        
        // 创建上传请求的URL，可能需要根据已上传的块动态构建
        NSURL *uploadURL = [NSURL URLWithString:@"http://example.com/upload"];
        
        // 设置请求的HTTP方法，通常为POST
        NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] requestWithMethod:@"POST" URLString:uploadURL.absoluteString parameters:nil error:nil];
        
        // 设置Content-Range头部，用于指示当前上传的块的范围
        NSString *contentRange = [NSString stringWithFormat:@"bytes %lu-%lu/%lu", (unsigned long)chunkRange.location, (unsigned long)(chunkRange.location + chunkRange.length - 1), (unsigned long)imageData.length];
        [request setValue:contentRange forHTTPHeaderField:@"Content-Range"];
        
        // 如果之前已经上传过一些块，设置Content-Range头部来告知服务器哪些块已经上传过
        if ([uploadedChunks count] > 0) {
            NSMutableString *ranges = [NSMutableString stringWithString:@"bytes "];
            [uploadedChunks enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
                if (idx > 0) {
                    [ranges appendString:@", "];
                }
                [ranges appendFormat:@"%lu-%lu", (unsigned long)(idx * chunkSize), (unsigned long)((idx + 1) * (chunkSize - 1))];
            }];
            [request setValue:[NSString stringWithFormat:@"bytes %@/%lu", ranges, (unsigned long)imageData.length] forHTTPHeaderField:@"Content-Range"];
        }
        
        // 上传当前块的数据
        NSURLSessionUploadTask *uploadTask = [manager uploadTaskWithRequest:request fromData:chunkData progress:nil completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
            if (!error) {
                // 块上传成功，添加到已上传块的集合中
                [uploadedChunks addIndex:chunkIndex];
                NSLog(@"Chunk %lu uploaded successfully.", (unsigned long)chunkIndex);
                
                // 检查是否所有块都已上传
                if ([uploadedChunks count] == totalChunks) {
                    NSLog(@"All chunks uploaded successfully.");
                    // 所有块上传完成，可以进行后续操作，比如通知服务器文件上传完成
                } else {
                    // 继续上传下一个块
                    //chunkIndex++;
                    if (chunkIndex < totalChunks) {
                        // 递归调用此方法来上传下一个块
                        // 注意：这里应该有一个更好的机制来管理上传任务，而不是简单的递归
                    }
                }
            } else {
                NSLog(@"Error uploading chunk %lu: %@", (unsigned long)chunkIndex, error);
                // 处理错误，可能需要重试上传失败的块
            }
        }];
        
        // 开始上传任务
        [uploadTask resume];
    }
}

@end
