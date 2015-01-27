/* Copyright 2014 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

private class Geary.ImapEngine.RevokableMove : Revokable {
    private GenericAccount account;
    private FolderPath original_source;
    private FolderPath original_dest;
    private Gee.Set<Imap.UID> destination_uids;
    
    public RevokableMove(GenericAccount account, FolderPath original_source, FolderPath original_dest,
        Gee.Set<Imap.UID> destination_uids) {
        this.account = account;
        this.original_source = original_source;
        this.original_dest = original_dest;
        this.destination_uids = destination_uids;
        
        account.folders_available_unavailable.connect(on_folders_available_unavailable);
        account.email_removed.connect(on_folder_email_removed);
    }
    
    ~RevokableMove() {
        account.folders_available_unavailable.disconnect(on_folders_available_unavailable);
        account.email_removed.disconnect(on_folder_email_removed);
    }
    
    public override async bool revoke_async(Cancellable? cancellable) throws Error {
        if (is_revoking)
            throw new EngineError.ALREADY_OPEN("Already revoking operation");
        
        is_revoking = true;
        try {
            return yield internal_revoke_async(cancellable);
        } finally {
            is_revoking = false;
        }
    }
    
    private async bool internal_revoke_async(Cancellable? cancellable) throws Error {
        // at this point, it's a one-shot deal: any error from here on out, or success, revoke
        // is spent
        can_revoke = false;
        
        // Use a detached Folder object, which bypasses synchronization on the destination folder
        // for "quick" operations
        Imap.Folder dest_folder = yield account.fetch_detached_folder_async(original_dest, cancellable);
        yield dest_folder.open_async(cancellable);
        
        // open, revoke, close, ensuring the close and signal disconnect are performed in all cases
        try {
            // watch out for messages detected as gone when folder is opened
            if (destination_uids.size > 0) {
                Gee.List<Imap.MessageSet> msg_sets = Imap.MessageSet.uid_sparse(destination_uids);
                
                // copy the moved email back to its source
                foreach (Imap.MessageSet msg_set in msg_sets)
                    yield dest_folder.copy_email_async(msg_set, original_source, cancellable);
                
                // remove it from the original destination in one fell swoop
                yield dest_folder.remove_email_async(msg_sets, cancellable);
            }
        } finally {
            // note that the Cancellable is not used
            try {
                yield dest_folder.close_async(null);
            } catch (Error err) {
                // ignored
            }
        }
        
        return can_revoke;
    }
    
    private void on_folders_available_unavailable(Gee.List<Folder>? available, Gee.List<Folder>? unavailable) {
        // look for either of the original folders going away
        if (unavailable != null) {
            foreach (Folder folder in unavailable) {
                if (folder.path.equal_to(original_source) || folder.path.equal_to(original_dest)) {
                    can_revoke = false;
                    
                    break;
                }
            }
        }
    }
    
    private void on_folder_email_removed(Folder folder, Gee.Collection<EmailIdentifier> ids) {
        // one-way switch, and only interested in destination folder activity
        if (!can_revoke || !folder.path.equal_to(original_dest))
            return;
        
        // convert generic identifiers to UIDs
        Gee.HashSet<Imap.UID> removed_uids = traverse<EmailIdentifier>(ids)
            .cast_object<ImapDB.EmailIdentifier>()
            .filter(id => id.uid == null)
            .map<Imap.UID>(id => id.uid)
            .to_hash_set();
        
        // otherwise, ability to revoke is best-effort
        destination_uids.remove_all(removed_uids);
        can_revoke = destination_uids.size > 0;
    }
}

