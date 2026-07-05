<?php
$models = ['Chat', 'ChatParticipant', 'Message', 'Notification', 'SubRoleCategory', 'UserSubRole', 'Opportunity', 'CreatorApplication', 'DashboardStat', 'Report', 'WalletTransaction', 'AuthLog', 'UserSession'];
foreach ($models as $model) {
    $file = __DIR__ . '/app/Models/' . $model . '.php';
    if (!file_exists($file)) {
        echo "Missing: $model\n";
        continue;
    }
    $content = file_get_contents($file);
    if (strpos($content, 'HasUuids') === false) {
        // Add import
        $content = str_replace("use Illuminate\Database\Eloquent\Model;", "use Illuminate\Database\Eloquent\Model;\nuse Illuminate\Database\Eloquent\Concerns\HasUuids;", $content);
        
        // Add trait
        if (strpos($content, 'use HasFactory;') !== false) {
            $content = str_replace('use HasFactory;', 'use HasFactory, HasUuids;', $content);
        } else {
            $content = preg_replace('/(class '.$model.' extends Model\n\{)/', "$1\n    use HasUuids;\n", $content);
        }
        file_put_contents($file, $content);
        echo "Updated $model\n";
    }
}
