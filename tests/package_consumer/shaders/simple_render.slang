#include "consumer_color.slang"

struct VertexOutput {
    float4 position : SV_Position;
};

[shader("vertex")]
VertexOutput consumer_vs(uint vertex_id : SV_VertexID) {
    const float2 positions[3] = {
        float2(0.0, -0.5),
        float2(0.5, 0.5),
        float2(-0.5, 0.5),
    };

    VertexOutput output;
    output.position = float4(positions[vertex_id], 0.0, 1.0);
    return output;
}

[shader("fragment")]
float4 consumer_fs() : SV_Target0 {
    return consumerColor();
}
